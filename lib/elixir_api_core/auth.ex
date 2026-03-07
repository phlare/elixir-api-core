defmodule ElixirApiCore.Auth do
  import Ecto.Query, warn: false

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Accounts.Membership
  alias ElixirApiCore.Accounts.User
  alias ElixirApiCore.Audit
  alias ElixirApiCore.Auth.Identity
  alias ElixirApiCore.Auth.Password
  alias ElixirApiCore.Auth.Tokens
  alias ElixirApiCore.Repo

  @min_password_length 8

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
    raw_token = get_param(params, :refresh_token)

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
