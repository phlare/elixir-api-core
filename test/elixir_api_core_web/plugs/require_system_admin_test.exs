defmodule ElixirApiCoreWeb.Plugs.RequireSystemAdminTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  alias ElixirApiCoreWeb.Plugs.RequireSystemAdmin

  test "passes through when user is system admin", %{conn: conn} do
    admin = ElixirApiCore.AccountsFixtures.system_admin_fixture()

    conn =
      conn
      |> assign(:current_user, admin)
      |> RequireSystemAdmin.call([])

    refute conn.halted
  end

  test "returns 403 when user is not system admin", %{conn: conn} do
    user = ElixirApiCore.AccountsFixtures.user_fixture()

    conn =
      conn
      |> assign(:current_user, user)
      |> RequireSystemAdmin.call([])

    assert conn.halted
    assert conn.status == 403
  end

  test "returns 403 when current_user is nil", %{conn: conn} do
    conn = RequireSystemAdmin.call(conn, [])

    assert conn.halted
    assert conn.status == 403
  end
end
