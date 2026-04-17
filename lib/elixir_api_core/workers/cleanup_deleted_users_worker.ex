defmodule ElixirApiCore.Workers.CleanupDeletedUsersWorker do
  @moduledoc """
  Scheduled daily. Finds soft-deleted users past the retention period and
  enqueues purge jobs to permanently remove their data.
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Workers.PurgeUserDataWorker

  @retention_days 30

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@retention_days, :day)
    expired_users = Accounts.list_expired_deleted_users(cutoff)

    Enum.each(expired_users, fn user ->
      %{"user_id" => user.id}
      |> PurgeUserDataWorker.new()
      |> Oban.insert!()
    end)

    Logger.info("CleanupDeletedUsersWorker: enqueued #{length(expired_users)} purge jobs")
    :ok
  end
end
