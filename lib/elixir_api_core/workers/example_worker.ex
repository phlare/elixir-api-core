defmodule ElixirApiCore.Workers.ExampleWorker do
  use Oban.Worker, queue: :default

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message" => message}}) do
    Logger.info("ExampleWorker performed: #{message}")
    :ok
  end
end
