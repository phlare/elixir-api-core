defmodule ElixirApiCoreWeb.Router do
  use ElixirApiCoreWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug ElixirApiCoreWeb.Plugs.Auth
  end

  # Health endpoints — no auth, no versioning
  scope "/", ElixirApiCoreWeb do
    pipe_through :api

    get "/healthz", HealthController, :healthz
    get "/readyz", HealthController, :readyz
  end

  # Public auth endpoints
  scope "/api/v1", ElixirApiCoreWeb do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    post "/auth/logout", AuthController, :logout
    get "/auth/google/start", AuthController, :google_start
    get "/auth/google/callback", AuthController, :google_callback
  end

  # Authenticated endpoints
  scope "/api/v1", ElixirApiCoreWeb do
    pipe_through [:api, :authenticated]

    post "/auth/switch_account", AuthController, :switch_account
    get "/me", UserController, :me
  end
end
