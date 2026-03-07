defmodule ElixirApiCore.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ElixirApiCore.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias ElixirApiCore.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ElixirApiCore.DataCase
      import ElixirApiCore.AccountsFixtures

      use Oban.Testing, repo: ElixirApiCore.Repo
    end
  end

  setup tags do
    ElixirApiCore.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(ElixirApiCore.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Sets up two isolated tenant contexts for cross-tenant leakage tests.

  Returns a map with `:account_a`, `:account_b`, `:user_a`, `:user_b`,
  `:membership_a`, and `:membership_b`. Use this to verify that queries
  scoped to one account never return data from the other.

  ## Example

      setup do
        {:ok, tenants: setup_tenant_pair()}
      end

      test "memberships are isolated", %{tenants: t} do
        results = Membership |> Repo.Scoped.scoped_all(t.account_a.id)
        assert Enum.all?(results, & &1.account_id == t.account_a.id)
      end
  """
  def setup_tenant_pair do
    alias ElixirApiCore.AccountsFixtures

    user_a = AccountsFixtures.user_fixture()
    user_b = AccountsFixtures.user_fixture()
    account_a = AccountsFixtures.account_fixture()
    account_b = AccountsFixtures.account_fixture()
    membership_a = AccountsFixtures.membership_fixture(%{user: user_a, account: account_a})
    membership_b = AccountsFixtures.membership_fixture(%{user: user_b, account: account_b})

    %{
      account_a: account_a,
      account_b: account_b,
      user_a: user_a,
      user_b: user_b,
      membership_a: membership_a,
      membership_b: membership_b
    }
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
