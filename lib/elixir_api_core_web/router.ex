defmodule ElixirApiCoreWeb.Router do
  use ElixirApiCoreWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth_security do
    plug ElixirApiCoreWeb.Plugs.SecurityHeaders
  end

  pipeline :authenticated do
    plug ElixirApiCoreWeb.Plugs.Auth
    plug ElixirApiCoreWeb.Plugs.RequireAccountScope
  end

  pipeline :system_admin do
    plug ElixirApiCoreWeb.Plugs.Auth
    plug ElixirApiCoreWeb.Plugs.RequireSystemAdmin
  end

  # Health endpoints — no auth, no versioning
  scope "/", ElixirApiCoreWeb do
    pipe_through :api

    get "/healthz", HealthController, :healthz
    get "/readyz", HealthController, :readyz
  end

  # Public auth endpoints
  scope "/api/v1", ElixirApiCoreWeb do
    pipe_through [:api, :auth_security]

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    post "/auth/logout", AuthController, :logout
    get "/auth/google/start", AuthController, :google_start
    get "/auth/google/callback", AuthController, :google_callback
    get "/auth/verify_email", AuthController, :verify_email
    post "/auth/request_password_reset", AuthController, :request_password_reset
    post "/auth/reset_password", AuthController, :reset_password
  end

  # Authenticated endpoints
  scope "/api/v1", ElixirApiCoreWeb do
    pipe_through [:api, :auth_security, :authenticated]

    post "/auth/switch_account", AuthController, :switch_account
    post "/auth/send_verification", AuthController, :send_verification
    get "/me", UserController, :me
    delete "/me", UserController, :delete_me
  end

  # System admin endpoints (no account scope required)
  scope "/api/v1/admin", ElixirApiCoreWeb.Admin do
    pipe_through [:api, :auth_security, :system_admin]

    get "/users", UsersController, :index
    get "/users/:id", UsersController, :show
    delete "/users/:id", UsersController, :delete
    post "/users/:id/restore", UsersController, :restore
    delete "/users/:id/purge", UsersController, :purge
  end
end
