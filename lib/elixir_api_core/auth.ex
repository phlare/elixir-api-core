defmodule ElixirApiCore.Auth do
  import Ecto.Query, warn: false

  require Logger

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Accounts.Membership
  alias ElixirApiCore.Accounts.User
  alias ElixirApiCore.Audit
  alias ElixirApiCore.Auth.EmailToken
  alias ElixirApiCore.Auth.Identity
  alias ElixirApiCore.Auth.Password
  alias ElixirApiCore.Auth.Tokens
  alias ElixirApiCore.Repo
  alias ElixirApiCore.Workers.SendEmailWorker

  @min_password_length 8
  @max_password_length 128

  @doc """
  Registers a new user with email/password.

  Creates a user, personal account, owner membership, and password identity,
  then issues access and refresh tokens.

  Returns `{:ok, result}` with user, account, membership, access_token, and
  refresh_token, or `{:error, reason}` on failure.
  """
  def register(params) do
    with {:ok, validated} <- validate_register_params(params) do
      password_hash = Password.hash_password(validated.password)

      Repo.transaction(fn ->
        with {:ok, user} <-
               Accounts.create_user(%{
                 email: validated.email,
                 display_name: validated.display_name
               }),
             {:ok, account} <-
               Accounts.create_account(%{
                 name: validated.account_name || default_account_name(validated.email)
               }),
             {:ok, membership} <-
               Accounts.create_membership(%{
                 user_id: user.id,
                 account_id: account.id,
                 role: :owner
               }),
             {:ok, _identity} <-
               insert_identity(%{
                 user_id: user.id,
                 provider: :password,
                 password_hash: password_hash
               }),
             {:ok, access_token, _claims} <-
               Tokens.issue_access_token(user.id, account.id, :owner),
             {:ok, refresh_result} <- Tokens.issue_refresh_token(user.id) do
          %{
            user: user,
            account: account,
            membership: membership,
            access_token: access_token,
            refresh_token: refresh_result.token
          }
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> with_audit(fn data ->
        %{
          action: "user.registered",
          actor_id: data.user.id,
          account_id: data.account.id,
          resource_type: "user",
          resource_id: data.user.id
        }
      end)
      |> enqueue_verification_on_register()
    end
  end

  defp enqueue_verification_on_register({:ok, %{user: user}} = result) do
    case enqueue_verification_email(user) do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to enqueue verification email for #{user.id}: #{inspect(reason)}")
    end

    result
  end

  defp enqueue_verification_on_register(other), do: other

  defp enqueue_verification_email(%User{id: user_id}) do
    token = EmailToken.sign_verification(user_id)

    %{"template" => "verification_email", "user_id" => user_id, "args" => %{"token" => token}}
    |> SendEmailWorker.new()
    |> Oban.insert()
  end

  defp enqueue_password_reset_email(%User{id: user_id}, %Identity{} = identity) do
    token = EmailToken.sign_password_reset(user_id, password_hash_fingerprint(identity))

    %{"template" => "password_reset_email", "user_id" => user_id, "args" => %{"token" => token}}
    |> SendEmailWorker.new()
    |> Oban.insert()
  end

  defp password_hash_fingerprint(%Identity{password_hash: hash}) when is_binary(hash),
    do: String.slice(hash, 0, 32)

  @doc """
  Enqueues a verification email for the given user.

  Returns `{:ok, job}` on successful enqueue. Safe to call repeatedly — each call
  enqueues a fresh signed token with a 24-hour TTL.
  """
  def send_verification_email(%User{email_verified_at: verified_at})
      when not is_nil(verified_at) do
    {:error, :email_already_verified}
  end

  def send_verification_email(%User{} = user) do
    case enqueue_verification_email(user) do
      {:ok, _job} ->
        {:ok, :enqueued}
        |> with_audit(fn _ ->
          %{
            action: "user.verification_email_sent",
            actor_id: user.id,
            resource_type: "user",
            resource_id: user.id
          }
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Verifies an email-verification token and marks the user's email as verified.

  Returns `{:ok, user}` on success, `{:error, :email_already_verified}` if the
  user was already verified, or `{:error, :invalid_email_token | :expired_email_token}`
  for token failures.
  """
  def verify_email(token) when is_binary(token) do
    with {:ok, user_id} <- EmailToken.verify_verification(token),
         {:ok, user} <- fetch_active_user(user_id),
         :ok <- ensure_not_verified(user),
         {:ok, verified_user} <-
           user |> User.verify_email_changeset() |> Repo.update() do
      {:ok, verified_user}
      |> with_audit(fn _ ->
        %{
          action: "user.email_verified",
          actor_id: verified_user.id,
          resource_type: "user",
          resource_id: verified_user.id
        }
      end)
    end
  end

  def verify_email(_), do: {:error, :invalid_email_token}

  @doc """
  Requests a password reset email for the given address.

  Always returns `{:ok, :enqueued}` regardless of whether an account exists for
  the email — this prevents account enumeration via the reset flow. If a user
  does exist and has a password identity, a reset email is enqueued.
  """
  def request_password_reset(email) when is_binary(email) do
    normalized = email |> String.trim() |> String.downcase()

    case Repo.get_by(User, email: normalized) do
      nil ->
        :ok

      %{deleted_at: d} when not is_nil(d) ->
        :ok

      %User{} = user ->
        case Repo.get_by(Identity, user_id: user.id, provider: :password) do
          nil ->
            :ok

          %Identity{} = identity ->
            case enqueue_password_reset_email(user, identity) do
              {:ok, _job} ->
                Audit.log(%{
                  action: "user.password_reset_requested",
                  actor_id: user.id,
                  resource_type: "user",
                  resource_id: user.id
                })

              {:error, reason} ->
                Logger.error(
                  "Failed to enqueue password reset for #{user.id}: #{inspect(reason)}"
                )
            end
        end
    end

    {:ok, :enqueued}
  end

  def request_password_reset(_), do: {:ok, :enqueued}

  @doc """
  Resets the password for a user identified by a signed reset token.

  Updates the user's `:password` identity. Returns `{:error, :no_password_identity}`
  if the user signed up via OAuth and has no password to reset.
  """
  def reset_password(token, new_password) when is_binary(token) and is_binary(new_password) do
    with :ok <- validate_password(new_password),
         {:ok, %{user_id: user_id, fingerprint: token_fingerprint}} <-
           EmailToken.verify_password_reset(token),
         {:ok, user} <- fetch_active_user(user_id),
         {:ok, identity} <- fetch_password_identity(user),
         :ok <- verify_password_fingerprint(identity, token_fingerprint),
         password_hash = Password.hash_password(new_password),
         {:ok, _updated} <-
           identity
           |> Identity.changeset(%{password_hash: password_hash})
           |> Repo.update() do
      Tokens.revoke_all_active_refresh_tokens(user.id)

      {:ok, user}
      |> with_audit(fn _ ->
        %{
          action: "user.password_reset",
          actor_id: user.id,
          resource_type: "user",
          resource_id: user.id
        }
      end)
    end
  end

  def reset_password(_, _), do: {:error, :invalid_email_token}

  defp fetch_active_user(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :invalid_email_token}
      %{deleted_at: d} when not is_nil(d) -> {:error, :invalid_email_token}
      user -> {:ok, user}
    end
  end

  defp ensure_not_verified(%User{email_verified_at: nil}), do: :ok
  defp ensure_not_verified(%User{}), do: {:error, :email_already_verified}

  defp fetch_password_identity(%User{} = user) do
    case Repo.get_by(Identity, user_id: user.id, provider: :password) do
      nil -> {:error, :no_password_identity}
      identity -> {:ok, identity}
    end
  end

  defp verify_password_fingerprint(%Identity{} = identity, token_fingerprint) do
    if password_hash_fingerprint(identity) == token_fingerprint do
      :ok
    else
      {:error, :invalid_email_token}
    end
  end

  defp validate_password(password) do
    cond do
      String.length(password) < @min_password_length -> {:error, :password_too_short}
      String.length(password) > @max_password_length -> {:error, :password_too_long}
      true -> :ok
    end
  end

  @doc """
  Authenticates a user by email/password.

  On success, issues access and refresh tokens for the user's first account
  and returns the full list of memberships (with preloaded accounts).
  """
  def login(params) do
    email = get_param(params, :email)
    password = get_param(params, :password)

    with {:ok, user} <- get_user_by_email(email),
         :ok <- verify_user_password(user, password) do
      memberships = get_user_memberships(user.id)

      case memberships do
        [] ->
          {:error, :no_active_membership}

        [active | _] ->
          with {:ok, access_token, _claims} <-
                 Tokens.issue_access_token(user.id, active.account_id, active.role),
               {:ok, refresh_result} <- Tokens.issue_refresh_token(user.id) do
            {:ok,
             %{
               user: user,
               access_token: access_token,
               refresh_token: refresh_result.token,
               active_account_id: active.account_id,
               active_role: active.role,
               memberships: memberships
             }}
          end
          |> with_audit(fn data ->
            %{
              action: "user.logged_in",
              actor_id: data.user.id,
              account_id: data.active_account_id,
              resource_type: "user",
              resource_id: data.user.id
            }
          end)
      end
    end
  end

  @doc """
  Rotates a refresh token and issues a new access token.

  Accepts an optional `account_id` to specify which account to issue the
  access token for. If omitted, defaults to the user's first membership.
  """
  def refresh(params) do
    raw_token = get_param(params, :refresh_token)

    with {:ok, rotate_result} <- Tokens.rotate_refresh_token(raw_token),
         {:ok, membership} <-
           resolve_membership(rotate_result.user_id, get_param(params, :account_id)),
         {:ok, access_token, _claims} <-
           Tokens.issue_access_token(
             rotate_result.user_id,
             membership.account_id,
             membership.role
           ) do
      {:ok,
       %{
         user_id: rotate_result.user_id,
         access_token: access_token,
         refresh_token: rotate_result.refresh_token,
         account_id: membership.account_id,
         role: membership.role
       }}
    end
    |> with_audit(fn data ->
      %{
        action: "token.refreshed",
        actor_id: data.user_id,
        account_id: data.account_id,
        resource_type: "refresh_token"
      }
    end)
  end

  @doc """
  Revokes a refresh token. Idempotent — revoking an already-revoked token succeeds.
  """
  def logout(params) do
    case get_param(params, :refresh_token) do
      nil ->
        {:error, :missing_refresh_token}

      raw_token ->
        Tokens.revoke_refresh_token(raw_token)
        |> with_audit(fn token ->
          %{
            action: "user.logged_out",
            actor_id: token.user_id,
            resource_type: "refresh_token",
            resource_id: token.id
          }
        end)
    end
  end

  @doc """
  Returns the Google OAuth authorize URL for redirecting the user.

  Uses the configured OAuth provider module (defaults to
  `ElixirApiCore.Auth.Providers.Google`).
  """
  def google_authorize_url do
    state = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)

    with {:ok, url} <- oauth_provider().authorize_url(state) do
      {:ok, {url, state}}
    end
  end

  @doc """
  Handles the Google OAuth callback.

  Exchanges the authorization code for user info, then applies linking rules:
  1. If a google identity with the provider_uid exists → login as that user
  2. If a user with the same email exists → link google identity to that user
  3. Otherwise → create a new user, account, membership, and google identity
  """
  def google_callback(params) do
    code = get_param(params, :code)

    with {:ok, user_info} <- oauth_provider().exchange_code(code) do
      case find_google_identity(user_info.provider_uid) do
        {:ok, identity} ->
          login_via_identity(identity)

        :not_found ->
          case Repo.get_by(User, email: String.downcase(user_info.email)) do
            nil ->
              create_google_user(user_info)

            %{deleted_at: d} when not is_nil(d) ->
              {:error, :invalid_credentials}

            existing_user ->
              link_google_identity(existing_user, user_info)
          end
      end
    end
  end

  defp find_google_identity(provider_uid) do
    case Repo.get_by(Identity, provider: :google, provider_uid: provider_uid) do
      nil -> :not_found
      identity -> {:ok, identity}
    end
  end

  defp login_via_identity(identity) do
    user = Repo.get!(User, identity.user_id)

    if not is_nil(user.deleted_at) do
      {:error, :invalid_credentials}
    else
      login_via_identity_user(user)
    end
  end

  defp login_via_identity_user(user) do
    memberships = get_user_memberships(user.id)

    case memberships do
      [] ->
        {:error, :no_active_membership}

      [active | _] ->
        with {:ok, access_token, _claims} <-
               Tokens.issue_access_token(user.id, active.account_id, active.role),
             {:ok, refresh_result} <- Tokens.issue_refresh_token(user.id) do
          {:ok,
           %{
             user: user,
             access_token: access_token,
             refresh_token: refresh_result.token,
             active_account_id: active.account_id,
             active_role: active.role,
             memberships: memberships
           }}
        end
        |> with_audit(fn data ->
          %{
            action: "user.logged_in_via_google",
            actor_id: data.user.id,
            account_id: data.active_account_id,
            resource_type: "user",
            resource_id: data.user.id
          }
        end)
    end
  end

  defp create_google_user(user_info) do
    Repo.transaction(fn ->
      with {:ok, user} <-
             Accounts.create_user(%{
               email: user_info.email,
               display_name: user_info.name
             }),
           {:ok, account} <-
             Accounts.create_account(%{
               name: default_account_name(user_info.email)
             }),
           {:ok, membership} <-
             Accounts.create_membership(%{
               user_id: user.id,
               account_id: account.id,
               role: :owner
             }),
           {:ok, _identity} <-
             insert_identity(%{
               user_id: user.id,
               provider: :google,
               provider_uid: user_info.provider_uid
             }),
           {:ok, access_token, _claims} <-
             Tokens.issue_access_token(user.id, account.id, :owner),
           {:ok, refresh_result} <- Tokens.issue_refresh_token(user.id) do
        %{
          user: user,
          account: account,
          membership: membership,
          access_token: access_token,
          refresh_token: refresh_result.token
        }
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> with_audit(fn data ->
      %{
        action: "user.registered_via_google",
        actor_id: data.user.id,
        account_id: data.account.id,
        resource_type: "user",
        resource_id: data.user.id
      }
    end)
  end

  defp link_google_identity(user, user_info) do
    with {:ok, _identity} <-
           insert_identity(%{
             user_id: user.id,
             provider: :google,
             provider_uid: user_info.provider_uid
           }) do
      memberships = get_user_memberships(user.id)

      case memberships do
        [] ->
          {:error, :no_active_membership}

        [active | _] ->
          with {:ok, access_token, _claims} <-
                 Tokens.issue_access_token(user.id, active.account_id, active.role),
               {:ok, refresh_result} <- Tokens.issue_refresh_token(user.id) do
            {:ok,
             %{
               user: user,
               access_token: access_token,
               refresh_token: refresh_result.token,
               active_account_id: active.account_id,
               active_role: active.role,
               memberships: memberships
             }}
          end
          |> with_audit(fn data ->
            %{
              action: "user.linked_google",
              actor_id: data.user.id,
              account_id: data.active_account_id,
              resource_type: "identity",
              resource_id: data.user.id
            }
          end)
      end
    end
  end

  defp oauth_provider do
    Application.get_env(
      :elixir_api_core,
      :oauth_provider,
      ElixirApiCore.Auth.Providers.Google
    )
  end

  @doc """
  Issues a new access token for a different account the user belongs to.

  The refresh token is unaffected (it is user-scoped, not account-scoped).
  """
  def switch_account(user_id, account_id)
      when is_binary(user_id) and is_binary(account_id) do
    case Repo.get_by(Membership, user_id: user_id, account_id: account_id) do
      nil ->
        {:error, :account_not_found}

      membership ->
        with {:ok, access_token, _claims} <-
               Tokens.issue_access_token(user_id, account_id, membership.role) do
          {:ok,
           %{
             access_token: access_token,
             account_id: account_id,
             role: membership.role
           }}
        end
        |> with_audit(fn data ->
          %{
            action: "account.switched",
            actor_id: user_id,
            account_id: data.account_id,
            resource_type: "account",
            resource_id: data.account_id
          }
        end)
    end
  end

  @doc """
  Self-service account deletion. Requires password confirmation (or typed phrase
  for OAuth-only users). Soft-deletes the user and their solely-owned accounts.
  """
  def delete_my_account(%User{} = user, params) do
    identities = Repo.all(from(i in Identity, where: i.user_id == ^user.id))
    has_password = Enum.any?(identities, &(&1.provider == :password))

    confirmation_result =
      if has_password do
        verify_user_password(user, get_param(params, :password))
      else
        text = get_param(params, :confirmation_text)

        if is_binary(text) and String.trim(text) |> String.downcase() == "delete my account" do
          :ok
        else
          {:error, :invalid_confirmation}
        end
      end

    with :ok <- confirmation_result,
         {:ok, _updated_user} <- Accounts.soft_delete_user(user) do
      {:ok, :deleted}
      |> with_audit(fn _ ->
        %{
          action: "user.self_deleted",
          actor_id: user.id,
          resource_type: "user",
          resource_id: user.id
        }
      end)
    end
  end

  defp validate_register_params(params) do
    password = get_param(params, :password)
    email = get_param(params, :email)
    display_name = get_param(params, :display_name)
    account_name = get_param(params, :account_name)

    cond do
      is_nil(password) or password == "" ->
        {:error, :password_required}

      String.length(password) < @min_password_length ->
        {:error, :password_too_short}

      String.length(password) > @max_password_length ->
        {:error, :password_too_long}

      true ->
        {:ok,
         %{
           email: email,
           password: password,
           display_name: display_name,
           account_name: account_name
         }}
    end
  end

  defp insert_identity(attrs) do
    %Identity{}
    |> Identity.changeset(attrs)
    |> Repo.insert()
  end

  defp default_account_name(email) when is_binary(email) do
    email |> String.split("@") |> List.first() |> Kernel.<>("'s Account")
  end

  defp default_account_name(_), do: "Personal Account"

  defp resolve_membership(user_id, nil) do
    case get_user_memberships(user_id) do
      [] -> {:error, :no_active_membership}
      [active | _] -> {:ok, active}
    end
  end

  defp resolve_membership(user_id, account_id) do
    case Repo.get_by(Membership, user_id: user_id, account_id: account_id) do
      nil -> {:error, :account_not_found}
      membership -> {:ok, membership}
    end
  end

  defp get_user_by_email(email) when is_binary(email) do
    case Repo.get_by(User, email: email |> String.trim() |> String.downcase()) do
      nil ->
        Password.verify_password("dummy", nil)
        {:error, :invalid_credentials}

      %{deleted_at: d} when not is_nil(d) ->
        Password.verify_password("dummy", nil)
        {:error, :invalid_credentials}

      user ->
        {:ok, user}
    end
  end

  defp get_user_by_email(_) do
    Password.verify_password("dummy", nil)
    {:error, :invalid_credentials}
  end

  defp verify_user_password(user, password) when is_binary(password) do
    case Repo.get_by(Identity, user_id: user.id, provider: :password) do
      nil ->
        Password.verify_password(password, nil)
        {:error, :invalid_credentials}

      %{password_hash: hash} ->
        if Password.verify_password(password, hash) do
          :ok
        else
          {:error, :invalid_credentials}
        end
    end
  end

  defp verify_user_password(_, _) do
    Password.verify_password("dummy", nil)
    {:error, :invalid_credentials}
  end

  defp get_user_memberships(user_id) do
    from(m in Membership,
      where: m.user_id == ^user_id,
      preload: [:account],
      order_by: [asc: m.inserted_at]
    )
    |> Repo.all()
  end

  defp with_audit({:ok, data} = result, attrs_fn) do
    Audit.log(attrs_fn.(data))
    result
  end

  defp with_audit(error, _attrs_fn), do: error

  defp get_param(params, key) when is_atom(key) do
    Map.get(params, key) || Map.get(params, Atom.to_string(key))
  end
end
