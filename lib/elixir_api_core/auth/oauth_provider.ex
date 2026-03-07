defmodule ElixirApiCore.Auth.OAuthProvider do
  @moduledoc """
  Behaviour for OAuth providers. Implementations handle provider-specific
  URL construction and code-for-profile exchange.
  """

  @type user_info :: %{
          email: String.t(),
          provider_uid: String.t(),
          name: String.t() | nil
        }

  @callback authorize_url(state :: String.t()) :: {:ok, String.t()} | {:error, term()}
  @callback exchange_code(code :: String.t()) :: {:ok, user_info()} | {:error, term()}
end
