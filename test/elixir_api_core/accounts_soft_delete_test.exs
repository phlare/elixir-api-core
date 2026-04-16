defmodule ElixirApiCore.AccountsSoftDeleteTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Accounts.{Account, User}
  alias ElixirApiCore.Auth.{Identity, RefreshToken}
  alias ElixirApiCore.Audit.Event

  describe "get_user/1" do
    test "returns user for non-deleted user" do
      user = user_fixture()
      assert %User{id: id} = Accounts.get_user(user.id)
      assert id == user.id
    end

    test "returns nil for soft-deleted user" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      {:ok, _} = Accounts.soft_delete_user(user)
      assert is_nil(Accounts.get_user(user.id))
    end

    test "returns nil for non-existent id" do
      assert is_nil(Accounts.get_user(Ecto.UUID.generate()))
    end
  end

  describe "get_user_including_deleted/1" do
    test "returns soft-deleted user" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      {:ok, _} = Accounts.soft_delete_user(user)
      assert %User{id: id} = Accounts.get_user_including_deleted(user.id)
      assert id == user.id
    end

    test "returns nil for non-existent id" do
      assert is_nil(Accounts.get_user_including_deleted(Ecto.UUID.generate()))
    end
  end

  describe "list_users/1" do
    test "excludes soft-deleted users by default" do
      user_a = user_fixture()
      user_b = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user_b, account: account, role: :owner})

      {:ok, _} = Accounts.soft_delete_user(user_b)

      result = Accounts.list_users()
      user_ids = Enum.map(result.users, & &1.id)
      assert user_a.id in user_ids
      refute user_b.id in user_ids
    end

    test "includes soft-deleted users when include_deleted: true" do
      user_a = user_fixture()
      user_b = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user_b, account: account, role: :owner})

      {:ok, _} = Accounts.soft_delete_user(user_b)

      result = Accounts.list_users(include_deleted: true)
      user_ids = Enum.map(result.users, & &1.id)
      assert user_a.id in user_ids
      assert user_b.id in user_ids
    end

    test "paginates results" do
      for _ <- 1..5, do: user_fixture()

      result = Accounts.list_users(page: 1, per_page: 2)
      assert length(result.users) == 2
      assert result.page == 1
      assert result.per_page == 2
      assert result.total >= 5

      result2 = Accounts.list_users(page: 2, per_page: 2)
      assert length(result2.users) == 2
      assert result2.page == 2
    end
  end

  describe "soft_delete_user/1" do
    test "sets deleted_at on the user" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      {:ok, deleted_user} = Accounts.soft_delete_user(user)
      assert not is_nil(deleted_user.deleted_at)
    end

    test "sets deleted_at on solely-owned accounts" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      {:ok, _} = Accounts.soft_delete_user(user)
      updated_account = Repo.get(Account, account.id)
      assert not is_nil(updated_account.deleted_at)
    end

    test "does not delete co-owned accounts" do
      user_a = user_fixture()
      user_b = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user_a, account: account, role: :owner})
      membership_fixture(%{user: user_b, account: account, role: :owner})

      {:ok, _} = Accounts.soft_delete_user(user_a)
      updated_account = Repo.get(Account, account.id)
      assert is_nil(updated_account.deleted_at)
    end

    test "revokes all refresh tokens" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})
      refresh_token_fixture(%{user: user})

      refresh_token_fixture(%{
        user: user,
        token_hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      })

      {:ok, _} = Accounts.soft_delete_user(user)

      active_tokens =
        from(t in RefreshToken,
          where: t.user_id == ^user.id and is_nil(t.revoked_at)
        )
        |> Repo.all()

      assert active_tokens == []
    end

    test "returns error for already-deleted user" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      {:ok, deleted_user} = Accounts.soft_delete_user(user)
      assert {:error, :user_already_deleted} = Accounts.soft_delete_user(deleted_user)
    end
  end

  describe "restore_user/1" do
    test "clears deleted_at on user and co-deleted accounts" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      {:ok, deleted_user} = Accounts.soft_delete_user(user)
      {:ok, restored_user} = Accounts.restore_user(deleted_user)

      assert is_nil(restored_user.deleted_at)
      updated_account = Repo.get(Account, account.id)
      assert is_nil(updated_account.deleted_at)
    end

    test "returns error for non-deleted user" do
      user = user_fixture()
      assert {:error, :user_not_deleted} = Accounts.restore_user(user)
    end
  end

  describe "purge_user!/1" do
    test "permanently removes user record" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      {:ok, _} = Accounts.purge_user!(user)
      assert is_nil(Repo.get(User, user.id))
    end

    test "deletes solely-owned accounts" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      {:ok, _} = Accounts.purge_user!(user)
      assert is_nil(Repo.get(Account, account.id))
    end

    test "cascades to identities and refresh tokens" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})
      identity_fixture(%{user: user})
      refresh_token_fixture(%{user: user})

      {:ok, _} = Accounts.purge_user!(user)

      assert Repo.all(from(i in Identity, where: i.user_id == ^user.id)) == []
      assert Repo.all(from(t in RefreshToken, where: t.user_id == ^user.id)) == []
    end

    test "deletes audit events for user and their accounts" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      # Create audit events
      Repo.insert!(%Event{
        action: "test.action",
        actor_id: user.id,
        account_id: account.id,
        resource_type: "user",
        resource_id: user.id
      })

      {:ok, _} = Accounts.purge_user!(user)

      assert Repo.all(from(e in Event, where: e.actor_id == ^user.id)) == []
      assert Repo.all(from(e in Event, where: e.account_id == ^account.id)) == []
    end

    test "removes memberships in other accounts" do
      user = user_fixture()
      other_user = user_fixture()
      own_account = account_fixture()
      other_account = account_fixture()
      membership_fixture(%{user: user, account: own_account, role: :owner})
      membership_fixture(%{user: other_user, account: other_account, role: :owner})
      membership_fixture(%{user: user, account: other_account, role: :member})

      {:ok, _} = Accounts.purge_user!(user)

      # Own account gone
      assert is_nil(Repo.get(Account, own_account.id))
      # Other account still exists
      assert not is_nil(Repo.get(Account, other_account.id))
      # User's membership in other account gone
      user_memberships =
        from(m in Accounts.Membership, where: m.user_id == ^user.id) |> Repo.all()

      assert user_memberships == []
    end
  end

  describe "list_expired_deleted_users/1" do
    test "returns users deleted before cutoff" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      {:ok, _} = Accounts.soft_delete_user(user)

      # Set deleted_at to 31 days ago
      past = DateTime.utc_now() |> DateTime.add(-31, :day)

      from(u in User, where: u.id == ^user.id)
      |> Repo.update_all(set: [deleted_at: past])

      cutoff = DateTime.utc_now() |> DateTime.add(-30, :day)
      expired = Accounts.list_expired_deleted_users(cutoff)
      assert Enum.any?(expired, &(&1.id == user.id))
    end

    test "excludes users deleted after cutoff" do
      user = user_fixture()
      account = account_fixture()
      membership_fixture(%{user: user, account: account, role: :owner})

      {:ok, _} = Accounts.soft_delete_user(user)

      cutoff = DateTime.utc_now() |> DateTime.add(-30, :day)
      expired = Accounts.list_expired_deleted_users(cutoff)
      refute Enum.any?(expired, &(&1.id == user.id))
    end
  end
end
