defmodule ElixirApiCore.Workers.PurgeUserDataWorker do
  @moduledoc """
  Permanently deletes a user and all associated data (GDPR right-to-erasure).
  Enqueued by admin purge endpoint or by the cleanup worker after retention period.
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 3

  require Logger

  alias ElixirApiCore.Accounts

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    case Accounts.get_user_including_deleted(user_id) do
      nil ->
        Logger.info("PurgeUserDataWorker: user #{user_id} already purged")
        :ok

      user ->
        {:ok, _} = Accounts.purge_user!(user)
        Logger.info("PurgeUserDataWorker: purged user #{user_id}")
        :ok
    end
  end
end
