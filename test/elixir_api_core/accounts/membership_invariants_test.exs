defmodule ElixirApiCore.Accounts.MembershipInvariantsTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Accounts.Membership
  alias ElixirApiCore.Repo

  describe "owner invariants" do
    test "prevents demoting the last owner in an account" do
      account = account_fixture()
      owner = membership_fixture(%{account: account, role: :owner})

      assert {:error, :last_owner_required} = Accounts.update_membership(owner, %{role: :member})
    end

    test "allows demoting an owner when another owner exists" do
      account = account_fixture()
      owner_a = membership_fixture(%{account: account, role: :owner})
      _owner_b = membership_fixture(%{account: account, role: :owner})

      assert {:ok, demoted} = Accounts.update_membership(owner_a, %{role: :member})
      assert demoted.role == :member
    end

    test "prevents deleting the last owner in an account" do
      account = account_fixture()
      owner = membership_fixture(%{account: account, role: :owner})

      assert {:error, :last_owner_required} = Accounts.delete_membership(owner)
      assert %Membership{} = Repo.get(Membership, owner.id)
    end

    test "allows deleting an owner when another owner exists" do
      account = account_fixture()
      owner_a = membership_fixture(%{account: account, role: :owner})
      _owner_b = membership_fixture(%{account: account, role: :owner})

      assert {:ok, deleted} = Accounts.delete_membership(owner_a)
      assert deleted.id == owner_a.id
      assert is_nil(Repo.get(Membership, owner_a.id))
    end

    test "allows deleting a non-owner membership" do
      account = account_fixture()
      _owner = membership_fixture(%{account: account, role: :owner})
      member = membership_fixture(%{account: account, role: :member})

      assert {:ok, deleted} = Accounts.delete_membership(member)
      assert deleted.id == member.id
      assert is_nil(Repo.get(Membership, member.id))
    end

    test "allows promoting a member to owner" do
      account = account_fixture()
      _owner = membership_fixture(%{account: account, role: :owner})
      member = membership_fixture(%{account: account, role: :member})

      assert {:ok, updated} = Accounts.update_membership(member, %{role: :owner})
      assert updated.role == :owner
    end

    test "rejects an update with an invalid role at changeset boundary" do
      account = account_fixture()
      member = membership_fixture(%{account: account, role: :member})

      assert {:error, changeset} = Accounts.update_membership(member, %{role: :superadmin})
      assert %{role: [_ | _]} = errors_on(changeset)
    end
  end

  describe "owner-count query short-circuit" do
    test "updating a non-owner membership issues fewer queries than updating an owner" do
      account = account_fixture()
      member = membership_fixture(%{account: account, role: :member})

      {member_count, {:ok, _}} =
        count_queries(fn -> Accounts.update_membership(member, %{role: :admin}) end)

      # Two owners required so demotion of owner_a is permitted
      owner_a = membership_fixture(%{account: account, role: :owner})
      _owner_b = membership_fixture(%{account: account, role: :owner})

      {owner_count, {:ok, _}} =
        count_queries(fn -> Accounts.update_membership(owner_a, %{role: :member}) end)

      # The owner path runs owner_count_for_update/1; the non-owner path short-circuits
      assert member_count < owner_count
    end
  end

  defp count_queries(fun) do
    ref = make_ref()
    handler_id = {__MODULE__, ref}
    Process.put({:query_count, ref}, 0)

    :telemetry.attach(
      handler_id,
      [:elixir_api_core, :repo, :query],
      fn _event, _measurements, _metadata, _config ->
        Process.put({:query_count, ref}, Process.get({:query_count, ref}, 0) + 1)
      end,
      nil
    )

    result = fun.()
    count = Process.get({:query_count, ref}, 0)
    :telemetry.detach(handler_id)
    {count, result}
  end
end
