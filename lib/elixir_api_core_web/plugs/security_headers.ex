defmodule ElixirApiCoreWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Sets security-related response headers on auth endpoints.

  - `x-content-type-options: nosniff` — prevents browsers from MIME-sniffing
    the response away from the declared content-type.
  - `cache-control: no-store` — ensures auth responses (which may contain
    tokens or user data) are never cached by browsers or proxies.

  ## Usage in router

      pipeline :auth_security do
        plug ElixirApiCoreWeb.Plugs.SecurityHeaders
      end
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("cache-control", "no-store")
  end
end
