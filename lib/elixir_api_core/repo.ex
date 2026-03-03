defmodule ElixirApiCore.Repo do
  use Ecto.Repo,
    otp_app: :elixir_api_core,
    adapter: Ecto.Adapters.Postgres
end
