defmodule ElixirApiCore.Workers.PurgeUserDataWorkerTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Accounts.User
  alias ElixirApiCore.Workers.PurgeUserDataWorker

  test "purges user when found" do
    user = user_fixture()
    account = account_fixture()
    membership_fixture(%{user: user, account: account, role: :owner})

    assert :ok = perform_job(PurgeUserDataWorker, %{"user_id" => user.id})
    assert is_nil(Repo.get(User, user.id))
  end

  test "returns :ok when user already purged (idempotent)" do
    assert :ok = perform_job(PurgeUserDataWorker, %{"user_id" => Ecto.UUID.generate()})
  end

  test "purges soft-deleted user" do
    user = user_fixture()
    account = account_fixture()
    membership_fixture(%{user: user, account: account, role: :owner})

    {:ok, _} = Accounts.soft_delete_user(user)
    assert :ok = perform_job(PurgeUserDataWorker, %{"user_id" => user.id})
    assert is_nil(Repo.get(User, user.id))
  end
end
