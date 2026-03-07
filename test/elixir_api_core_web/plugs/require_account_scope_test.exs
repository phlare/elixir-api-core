defmodule ElixirApiCoreWeb.Plugs.RequireAccountScopeTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  alias ElixirApiCoreWeb.Plugs.RequireAccountScope

  describe "call/2" do
    test "passes through when current_account_id is set", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:current_account_id, Ecto.UUID.generate())
        |> RequireAccountScope.call([])

      refute conn.halted
    end

    test "halts with 403 when current_account_id is missing", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> RequireAccountScope.call([])

      assert conn.halted
      assert conn.status == 403
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["code"] == "missing_account_scope"
    end

    test "halts with 403 when current_account_id is nil", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:current_account_id, nil)
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> RequireAccountScope.call([])

      assert conn.halted
      assert conn.status == 403
    end
  end
end
