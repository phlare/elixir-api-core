defmodule ElixirApiCore.Auth.Cookie do
  @moduledoc """
  Helpers for refresh token cookie transport.

  Reads configuration from `config :elixir_api_core, ElixirApiCore.Auth.Cookie`.
  When `enabled: true`, auth endpoints set an HttpOnly cookie alongside the
  JSON body refresh token. The refresh endpoint reads from the cookie when
  no `refresh_token` param is present in the request body.
  """

  @doc "Returns true if cookie transport is enabled."
  def enabled? do
    config(:enabled, true)
  end

  @doc "Returns the cookie name."
  def name do
    config(:name, "_refresh_token")
  end

  @doc "Returns whether cookies should use the Secure flag."
  def secure? do
    config(:secure, false)
  end

  @doc "Returns cookie options for Plug.Conn.put_resp_cookie/4."
  def options do
    [
      http_only: config(:http_only, true),
      secure: config(:secure, false),
      same_site: config(:same_site, "Strict"),
      max_age: config(:max_age, 604_800),
      path: config(:path, "/api/v1/auth")
    ]
  end

  @doc "Returns cookie options that expire the cookie immediately (for logout)."
  def delete_options do
    Keyword.put(options(), :max_age, 0)
  end

  defp config(key, default) do
    :elixir_api_core
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end
end
