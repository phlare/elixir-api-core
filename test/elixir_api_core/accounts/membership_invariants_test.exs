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
  end
end
