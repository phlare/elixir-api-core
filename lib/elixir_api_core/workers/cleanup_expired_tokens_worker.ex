defmodule ElixirApiCore.Workers.CleanupExpiredTokensWorker do
  use Oban.Worker, queue: :maintenance

  require Logger
  import Ecto.Query

  alias ElixirApiCore.Auth.RefreshToken
  alias ElixirApiCore.Repo

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    {count, _} =
      from(rt in RefreshToken,
        where: rt.expires_at < ^now or not is_nil(rt.revoked_at)
      )
      |> Repo.delete_all()

    Logger.info("CleanupExpiredTokensWorker deleted #{count} tokens")
    :ok
  end
end
