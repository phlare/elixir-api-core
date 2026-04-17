defmodule ElixirApiCore.Auth.EmailToken do
  @moduledoc """
  Stateless signed tokens for email flows (verification, password reset).

  Wraps `Phoenix.Token` with per-flow salts and TTLs from config. Verification
  tokens carry only the user ID. Password-reset tokens additionally carry a
  fingerprint of the current password hash so that the token is invalidated as
  soon as the password changes (single-use semantics without a DB round trip).
  """

  alias ElixirApiCoreWeb.Endpoint

  @verification_salt "email verification"
  @password_reset_salt "password reset"

  def sign_verification(user_id) when is_binary(user_id) do
    Phoenix.Token.sign(Endpoint, @verification_salt, user_id)
  end

  def verify_verification(token) when is_binary(token) do
    case Phoenix.Token.verify(Endpoint, @verification_salt, token,
           max_age: ttl(:email_verification_ttl_seconds)
         ) do
      {:ok, user_id} when is_binary(user_id) -> {:ok, user_id}
      {:error, :expired} -> {:error, :expired_email_token}
      {:error, _} -> {:error, :invalid_email_token}
    end
  end

  def verify_verification(_), do: {:error, :invalid_email_token}

  @doc """
  Signs a password-reset token for `user_id`, binding it to the current
  password-hash fingerprint. After the password is changed the fingerprint
  will no longer match and the token is rejected — giving the token one-shot
  semantics without a nonce table.
  """
  def sign_password_reset(user_id, fingerprint)
      when is_binary(user_id) and is_binary(fingerprint) do
    Phoenix.Token.sign(Endpoint, @password_reset_salt, {user_id, fingerprint})
  end

  def verify_password_reset(token) when is_binary(token) do
    case Phoenix.Token.verify(Endpoint, @password_reset_salt, token,
           max_age: ttl(:password_reset_ttl_seconds)
         ) do
      {:ok, {user_id, fingerprint}} when is_binary(user_id) and is_binary(fingerprint) ->
        {:ok, %{user_id: user_id, fingerprint: fingerprint}}

      {:error, :expired} ->
        {:error, :expired_email_token}

      {:error, _} ->
        {:error, :invalid_email_token}

      _ ->
        {:error, :invalid_email_token}
    end
  end

  def verify_password_reset(_), do: {:error, :invalid_email_token}

  defp ttl(key) do
    Application.get_env(:elixir_api_core, ElixirApiCore.Auth.Tokens, [])
    |> Keyword.fetch!(key)
  end
end
