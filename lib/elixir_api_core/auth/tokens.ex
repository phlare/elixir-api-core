defmodule ElixirApiCore.Auth.Tokens do
  import Ecto.Query, warn: false

  alias ElixirApiCore.Auth.RefreshToken
  alias ElixirApiCore.Repo

  @valid_roles ~w(owner admin member)

  @type access_claims :: %{
          user_id: String.t(),
          account_id: String.t(),
          role: String.t(),
          exp: pos_integer(),
          iat: pos_integer(),
          iss: String.t(),
          jti: String.t()
        }

  @type rotate_result :: %{
          user_id: String.t(),
          refresh_token: String.t(),
          refresh_token_record: RefreshToken.t()
        }

  def issue_access_token(user_id, account_id, role, opts \\ [])
      when is_binary(user_id) and is_binary(account_id) do
    with {:ok, normalized_role} <- normalize_role(role) do
      now = now(opts)
      ttl_seconds = Keyword.get(opts, :ttl_seconds, config(:access_token_ttl_seconds, 900))
      issued_at = DateTime.to_unix(now)
      expires_at = DateTime.to_unix(DateTime.add(now, ttl_seconds, :second))

      claims = %{
        "sub" => user_id,
        "user_id" => user_id,
        "account_id" => account_id,
        "role" => normalized_role,
        "iat" => issued_at,
        "exp" => expires_at,
        "iss" => config(:jwt_issuer, "elixir_api_core"),
        "jti" => Ecto.UUID.generate()
      }

      case sign_jwt(claims) do
        {:ok, token} -> {:ok, token, claims}
        {:error, _reason} = error -> error
      end
    end
  end

  def verify_access_token(token, opts \\ []) when is_binary(token) do
    now_unix = DateTime.to_unix(now(opts))

    with {:ok, claims} <- verify_signature(token),
         :ok <- validate_issuer(claims),
         :ok <- validate_expiration(claims, now_unix),
         {:ok, decoded_claims} <- decode_claims(claims) do
      {:ok, decoded_claims}
    end
  end

  def issue_refresh_token(user_id, opts \\ []) when is_binary(user_id) do
    raw_token = generate_refresh_token()
    token_hash = hash_refresh_token(raw_token)
    now = now(opts)
    ttl_seconds = Keyword.get(opts, :ttl_seconds, config(:refresh_token_ttl_seconds, 2_592_000))
    expires_at = DateTime.add(now, ttl_seconds, :second)

    attrs = %{
      user_id: user_id,
      token_hash: token_hash,
      expires_at: expires_at
    }

    case %RefreshToken{} |> RefreshToken.changeset(attrs, now: now) |> Repo.insert() do
      {:ok, refresh_token} ->
        {:ok, %{token: raw_token, refresh_token: refresh_token}}

      {:error, _changeset} = error ->
        error
    end
  end

  def rotate_refresh_token(raw_token, opts \\ []) when is_binary(raw_token) do
    token_hash = hash_refresh_token(raw_token)
    now = now(opts)

    Repo.transaction(fn ->
      case get_refresh_token_for_update(token_hash) do
        nil ->
          Repo.rollback(:invalid_refresh_token)

        token ->
          cond do
            not is_nil(token.revoked_at) ->
              revoke_all_active_refresh_tokens(token.user_id, now)
              {:refresh_token_reuse_detected, token.user_id}

            DateTime.compare(token.expires_at, now) == :lt ->
              Repo.rollback(:expired_refresh_token)

            true ->
              revoke_refresh_token_record!(token, now)

              case issue_refresh_token(token.user_id, now: now) do
                {:ok, issued} ->
                  %{
                    user_id: token.user_id,
                    refresh_token: issued.token,
                    refresh_token_record: issued.refresh_token
                  }

                {:error, changeset} ->
                  Repo.rollback({:invalid_changeset, changeset})
              end
          end
      end
    end)
    |> normalize_rotate_result()
  end

  def revoke_refresh_token(raw_token, opts \\ []) when is_binary(raw_token) do
    token_hash = hash_refresh_token(raw_token)
    now = now(opts)

    case Repo.get_by(RefreshToken, token_hash: token_hash) do
      nil ->
        {:error, :invalid_refresh_token}

      token when not is_nil(token.revoked_at) ->
        {:ok, token}

      token ->
        token
        |> RefreshToken.changeset(%{revoked_at: now})
        |> Repo.update()
    end
  end

  def revoke_all_active_refresh_tokens(user_id, now \\ DateTime.utc_now())
      when is_binary(user_id) do
    from(r in RefreshToken,
      where:
        r.user_id == ^user_id and is_nil(r.revoked_at) and
          r.expires_at > ^now
    )
    |> Repo.update_all(set: [revoked_at: now, updated_at: now])
  end

  def refresh_token_status(raw_token, opts \\ []) when is_binary(raw_token) do
    token_hash = hash_refresh_token(raw_token)
    now = now(opts)

    case Repo.get_by(RefreshToken, token_hash: token_hash) do
      nil -> :missing
      token when not is_nil(token.revoked_at) -> :revoked
      token -> if DateTime.compare(token.expires_at, now) == :lt, do: :expired, else: :active
    end
  end

  def hash_refresh_token(raw_token) when is_binary(raw_token) do
    pepper = config(:refresh_token_pepper, "dev_refresh_pepper_change_me")

    :crypto.mac(:hmac, :sha256, pepper, raw_token)
    |> Base.encode16(case: :lower)
  end

  def generate_refresh_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp sign_jwt(claims) do
    jwk = JOSE.JWK.from_oct(jwt_secret())
    header = %{"alg" => config(:jwt_algorithm, "HS256"), "typ" => "JWT"}

    {_, compact_token} = JOSE.JWT.sign(jwk, header, claims) |> JOSE.JWS.compact()
    {:ok, compact_token}
  rescue
    _error -> {:error, :token_signing_failed}
  end

  defp verify_signature(token) do
    jwk = JOSE.JWK.from_oct(jwt_secret())
    algorithm = config(:jwt_algorithm, "HS256")

    case JOSE.JWT.verify_strict(jwk, [algorithm], token) do
      {true, %JOSE.JWT{fields: claims}, _jws} -> {:ok, claims}
      _ -> {:error, :invalid_token}
    end
  rescue
    _error -> {:error, :invalid_token}
  end

  defp validate_issuer(%{"iss" => issuer}) do
    if issuer == config(:jwt_issuer, "elixir_api_core"), do: :ok, else: {:error, :invalid_token}
  end

  defp validate_issuer(_claims), do: {:error, :invalid_token}

  defp validate_expiration(%{"exp" => exp}, now_unix) when is_integer(exp) do
    if exp > now_unix, do: :ok, else: {:error, :expired_token}
  end

  defp validate_expiration(_claims, _now_unix), do: {:error, :invalid_token}

  defp decode_claims(claims) do
    user_id = claims["user_id"]
    account_id = claims["account_id"]
    role = claims["role"]
    exp = claims["exp"]
    iat = claims["iat"]
    iss = claims["iss"]
    jti = claims["jti"]

    if is_binary(user_id) and is_binary(account_id) and is_binary(role) and role in @valid_roles and
         is_integer(exp) and is_integer(iat) and is_binary(iss) and is_binary(jti) do
      {:ok,
       %{
         user_id: user_id,
         account_id: account_id,
         role: role,
         exp: exp,
         iat: iat,
         iss: iss,
         jti: jti
       }}
    else
      {:error, :invalid_token}
    end
  end

  defp get_refresh_token_for_update(token_hash) do
    from(r in RefreshToken, where: r.token_hash == ^token_hash, lock: "FOR UPDATE")
    |> Repo.one()
  end

  defp revoke_refresh_token_record!(token, now) do
    token
    |> RefreshToken.changeset(%{revoked_at: now})
    |> Repo.update!()
  end

  defp normalize_rotate_result({:ok, {:refresh_token_reuse_detected, _user_id}}),
    do: {:error, :refresh_token_reuse_detected}

  defp normalize_rotate_result({:ok, %{} = result}), do: {:ok, result}

  defp normalize_rotate_result({:error, :invalid_refresh_token}),
    do: {:error, :invalid_refresh_token}

  defp normalize_rotate_result({:error, :expired_refresh_token}),
    do: {:error, :expired_refresh_token}

  defp normalize_rotate_result({:error, :refresh_token_reuse_detected}),
    do: {:error, :refresh_token_reuse_detected}

  defp normalize_rotate_result({:error, {:invalid_changeset, changeset}}), do: {:error, changeset}

  defp normalize_role(role) when is_atom(role), do: normalize_role(Atom.to_string(role))

  defp normalize_role(role) when is_binary(role) do
    if role in @valid_roles, do: {:ok, role}, else: {:error, :invalid_role}
  end

  defp normalize_role(_role), do: {:error, :invalid_role}

  defp now(opts) do
    opts
    |> Keyword.get(:now, DateTime.utc_now())
    |> DateTime.truncate(:second)
  end

  defp config(key, default) do
    Application.get_env(:elixir_api_core, __MODULE__, [])
    |> Keyword.get(key, default)
  end

  defp jwt_secret do
    config(:jwt_secret, "dev_jwt_secret_change_me")
  end
end
