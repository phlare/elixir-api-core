defmodule ElixirApiCore.Workers.CleanupExpiredTokensWorkerTest do
  use ElixirApiCore.DataCase, async: true

  import ElixirApiCore.AccountsFixtures

  alias ElixirApiCore.Auth.RefreshToken
  alias ElixirApiCore.Workers.CleanupExpiredTokensWorker

  test "is scheduled via Oban Cron plugin" do
    oban_config = Application.fetch_env!(:elixir_api_core, Oban)
    plugins = Keyword.get(oban_config, :plugins, [])

    cron_plugin =
      Enum.find_value(plugins, fn
        {Oban.Plugins.Cron, opts} -> opts
        _ -> nil
      end)

    assert cron_plugin, "Oban.Plugins.Cron not configured"

    crontab = Keyword.get(cron_plugin, :crontab, [])

    assert Enum.any?(crontab, fn {_schedule, worker} ->
             worker == CleanupExpiredTokensWorker
           end)
  end

  test "deletes expired tokens" do
    user = user_fixture()

    # Expired token (bypass changeset validation via direct insert)
    expired =
      Repo.insert!(%RefreshToken{
        user_id: user.id,
        token_hash: String.duplicate("e", 64),
        expires_at: DateTime.add(DateTime.utc_now(), -3600) |> DateTime.truncate(:second)
      })

    # Active token
    active =
      refresh_token_fixture(%{user: user, token_hash: String.duplicate("a", 64)})

    assert :ok = perform_job(CleanupExpiredTokensWorker, %{})

    assert Repo.get(RefreshToken, active.id)
    refute Repo.get(RefreshToken, expired.id)
  end

  test "deletes revoked tokens" do
    user = user_fixture()

    revoked =
      Repo.insert!(%RefreshToken{
        user_id: user.id,
        token_hash: String.duplicate("r", 64),
        expires_at: DateTime.add(DateTime.utc_now(), 86_400) |> DateTime.truncate(:second),
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    assert :ok = perform_job(CleanupExpiredTokensWorker, %{})

    refute Repo.get(RefreshToken, revoked.id)
  end
end
