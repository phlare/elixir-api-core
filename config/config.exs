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
  refresh_token_ttl_seconds: 604_800,
  refresh_token_pepper: "dev_refresh_pepper_change_me",
  email_verification_ttl_seconds: 86_400,
  password_reset_ttl_seconds: 3_600

config :elixir_api_core, ElixirApiCore.Auth.Cookie,
  enabled: true,
  name: "_refresh_token",
  path: "/api/v1/auth",
  http_only: true,
  secure: false,
  same_site: "Strict",
  max_age: 604_800

config :elixir_api_core, ElixirApiCore.Auth.RateLimits,
  login_limit: 5,
  login_window_seconds: 60,
  refresh_limit: 10,
  refresh_window_seconds: 60,
  send_verification_limit: 3,
  send_verification_window_seconds: 300,
  password_reset_limit: 3,
  password_reset_window_seconds: 300

config :elixir_api_core, Oban,
  repo: ElixirApiCore.Repo,
  queues: [default: 10, maintenance: 5, email: 5],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * *", ElixirApiCore.Workers.CleanupExpiredTokensWorker},
       {"0 4 * * *", ElixirApiCore.Workers.CleanupDeletedUsersWorker}
     ]}
  ]

# Email (Swoosh) — provider-agnostic. Dev uses Local adapter (Swoosh mailbox
# viewer at http://localhost:4001); test uses the Test adapter. Downstream
# projects add their own production adapter dep and config in runtime.exs.
config :elixir_api_core, ElixirApiCore.Mailer, adapter: Swoosh.Adapters.Local

config :elixir_api_core, ElixirApiCore.Email,
  from_email: "noreply@example.com",
  app_url: "http://localhost:5173"

config :swoosh, :api_client, false

# CORS — restrictive default; override in runtime.exs for prod
config :cors_plug,
  origin: ["http://localhost:3000", "http://localhost:5173"],
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
  headers: ["Authorization", "Content-Type"],
  credentials: true

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
