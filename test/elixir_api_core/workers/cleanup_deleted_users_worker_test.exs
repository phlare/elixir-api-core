defmodule ElixirApiCore.Workers.CleanupDeletedUsersWorkerTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Accounts.User
  alias ElixirApiCore.Workers.CleanupDeletedUsersWorker

  test "purges users deleted past retention period (inline mode executes immediately)" do
    user = user_fixture()
    account = account_fixture()
    membership_fixture(%{user: user, account: account, role: :owner})

    {:ok, _} = Accounts.soft_delete_user(user)

    # Backdate deleted_at to 31 days ago
    past = DateTime.utc_now() |> DateTime.add(-31, :day)
    from(u in User, where: u.id == ^user.id) |> Repo.update_all(set: [deleted_at: past])

    # In inline mode, the enqueued PurgeUserDataWorker runs immediately
    assert :ok = perform_job(CleanupDeletedUsersWorker, %{})

    # Verify the user was purged (side effect of inline execution)
    assert is_nil(Repo.get(User, user.id))
  end

  test "does not purge recently deleted users" do
    user = user_fixture()
    account = account_fixture()
    membership_fixture(%{user: user, account: account, role: :owner})

    {:ok, _} = Accounts.soft_delete_user(user)

    assert :ok = perform_job(CleanupDeletedUsersWorker, %{})

    # User should still exist (deleted recently, within retention period)
    assert not is_nil(Repo.get(User, user.id))
  end

  test "does not purge non-deleted users" do
    user = user_fixture()

    assert :ok = perform_job(CleanupDeletedUsersWorker, %{})
    assert not is_nil(Repo.get(User, user.id))
  end

  test "cleanup worker is registered in Oban cron config" do
    oban_config = Application.get_env(:elixir_api_core, Oban)
    plugins = Keyword.get(oban_config, :plugins, [])

    cron_plugin =
      Enum.find(plugins, fn
        {Oban.Plugins.Cron, _opts} -> true
        _ -> false
      end)

    assert {Oban.Plugins.Cron, opts} = cron_plugin
    crontab = Keyword.get(opts, :crontab, [])

    assert Enum.any?(crontab, fn {_schedule, worker} ->
             worker == ElixirApiCore.Workers.CleanupDeletedUsersWorker
           end)
  end
end
