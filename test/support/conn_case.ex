defmodule ElixirApiCoreWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ElixirApiCoreWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias ElixirApiCore.Auth.Tokens
  alias ElixirApiCore.AccountsFixtures

  using do
    quote do
      # The default endpoint for testing
      @endpoint ElixirApiCoreWeb.Endpoint

      use ElixirApiCoreWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ElixirApiCoreWeb.ConnCase
    end
  end

  setup tags do
    ElixirApiCore.DataCase.setup_sandbox(tags)
    ElixirApiCore.Auth.RateLimiter.reset()
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Adds a valid bearer token to the conn for controller tests.
  """
  def conn_with_token(conn, opts \\ []) do
    membership = Keyword.get_lazy(opts, :membership, &build_membership/0)
    role = Keyword.get(opts, :role, membership.role)

    {:ok, token, _claims} =
      Tokens.issue_access_token(membership.user_id, membership.account_id, role)

    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc """
  Adds a valid bearer token for a system admin user.
  Returns {conn, user} so tests can reference the admin user.
  """
  def conn_with_admin_token(conn) do
    admin = AccountsFixtures.system_admin_fixture()
    account = AccountsFixtures.account_fixture()

    membership =
      AccountsFixtures.membership_fixture(%{
        user: admin,
        account: account,
        role: :owner
      })

    {:ok, token, _claims} =
      Tokens.issue_access_token(admin.id, membership.account_id, membership.role)

    conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
    {conn, admin}
  end

  defp build_membership do
    user = AccountsFixtures.user_fixture()
    account = AccountsFixtures.account_fixture()

    AccountsFixtures.membership_fixture(%{
      user: user,
      account: account,
      role: :owner
    })
  end
end
