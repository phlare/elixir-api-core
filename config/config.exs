# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :elixir_api_core,
  env: config_env(),
  ecto_repos: [ElixirApiCore.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :elixir_api_core, ElixirApiCore.Auth.Tokens,
  jwt_algorithm: "HS256",
  jwt_issuer: "elixir_api_core",
  jwt_secret: "dev_jwt_secret_change_me",
  access_token_ttl_seconds: 900,
  refresh_token_ttl_seconds: 2_592_000,
  refresh_token_pepper: "dev_refresh_pepper_change_me"

config :elixir_api_core, ElixirApiCore.Auth.RateLimits,
  login_limit: 5,
  login_window_seconds: 60,
  refresh_limit: 10,
  refresh_window_seconds: 60

config :elixir_api_core, Oban,
  repo: ElixirApiCore.Repo,
  queues: [default: 10, maintenance: 5]

# Configure the endpoint
config :elixir_api_core, ElixirApiCoreWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: ElixirApiCoreWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ElixirApiCore.PubSub,
  live_view: [signing_salt: "qdM1gjYK"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
