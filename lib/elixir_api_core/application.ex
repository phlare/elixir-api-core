defmodule ElixirApiCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixirApiCoreWeb.Telemetry,
      ElixirApiCore.Repo,
      {DNSCluster, query: Application.get_env(:elixir_api_core, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixirApiCore.PubSub},
      ElixirApiCore.Auth.RateLimiter,
      # Start a worker by calling: ElixirApiCore.Worker.start_link(arg)
      # {ElixirApiCore.Worker, arg},
      # Start to serve requests, typically the last entry
      ElixirApiCoreWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirApiCore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixirApiCoreWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
