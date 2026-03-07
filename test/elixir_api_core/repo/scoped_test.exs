defmodule ElixirApiCore.Repo.ScopedTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Accounts.Membership
  alias ElixirApiCore.Repo.Scoped

  setup do
    {:ok, tenants: setup_tenant_pair()}
  end

  describe "where_account/2" do
    test "filters query to a single account", %{tenants: t} do
      results = Membership |> Scoped.where_account(t.account_a.id) |> Repo.all()

      assert length(results) == 1
      assert hd(results).account_id == t.account_a.id
    end

    test "returns empty when account has no matching records", %{tenants: _t} do
      empty_account = account_fixture()
      results = Membership |> Scoped.where_account(empty_account.id) |> Repo.all()

      assert results == []
    end
  end

  describe "scoped_get/3" do
    test "returns record when it belongs to the account", %{tenants: t} do
      result = Scoped.scoped_get(Membership, t.membership_a.id, t.account_a.id)

      assert result.id == t.membership_a.id
    end

    test "returns nil when record belongs to a different account", %{tenants: t} do
      result = Scoped.scoped_get(Membership, t.membership_a.id, t.account_b.id)

      assert result == nil
    end
  end

  describe "scoped_get!/3" do
    test "returns record when it belongs to the account", %{tenants: t} do
      result = Scoped.scoped_get!(Membership, t.membership_a.id, t.account_a.id)

      assert result.id == t.membership_a.id
    end

    test "raises when record belongs to a different account", %{tenants: t} do
      assert_raise Ecto.NoResultsError, fn ->
        Scoped.scoped_get!(Membership, t.membership_a.id, t.account_b.id)
      end
    end
  end

  describe "scoped_get_by/3" do
    test "finds record matching clauses within account", %{tenants: t} do
      result =
        Scoped.scoped_get_by(Membership, [user_id: t.user_a.id], t.account_a.id)

      assert result.id == t.membership_a.id
    end

    test "returns nil when clauses match but wrong account", %{tenants: t} do
      result =
        Scoped.scoped_get_by(Membership, [user_id: t.user_a.id], t.account_b.id)

      assert result == nil
    end
  end

  describe "scoped_all/2" do
    test "returns only records for the specified account", %{tenants: t} do
      results = Scoped.scoped_all(Membership, t.account_a.id)

      assert length(results) == 1
      assert Enum.all?(results, &(&1.account_id == t.account_a.id))
    end

    test "never returns records from another account", %{tenants: t} do
      results_a = Scoped.scoped_all(Membership, t.account_a.id)
      results_b = Scoped.scoped_all(Membership, t.account_b.id)

      ids_a = MapSet.new(results_a, & &1.id)
      ids_b = MapSet.new(results_b, & &1.id)

      assert MapSet.disjoint?(ids_a, ids_b)
    end
  end

  describe "tenant isolation" do
    test "cross-account access is impossible via scoped helpers", %{tenants: t} do
      # Account A's membership cannot be fetched through account B's scope
      assert Scoped.scoped_get(Membership, t.membership_a.id, t.account_b.id) == nil
      assert Scoped.scoped_get(Membership, t.membership_b.id, t.account_a.id) == nil

      # Scoped queries only return own-account data
      all_a = Scoped.scoped_all(Membership, t.account_a.id)
      assert Enum.all?(all_a, &(&1.account_id == t.account_a.id))

      all_b = Scoped.scoped_all(Membership, t.account_b.id)
      assert Enum.all?(all_b, &(&1.account_id == t.account_b.id))
    end
  end
end
