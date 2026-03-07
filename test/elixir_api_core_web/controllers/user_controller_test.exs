defmodule ElixirApiCoreWeb.UserControllerTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  describe "GET /api/v1/me" do
    test "returns current user and account context", %{conn: conn} do
      conn = conn_with_token(conn)

      conn = get(conn, "/api/v1/me")
      resp = json_response(conn, 200)

      assert resp["data"]["user"]["id"]
      assert resp["data"]["user"]["email"]
      assert resp["data"]["account_id"]
      assert resp["data"]["role"]
      assert resp["data"]["membership_id"]
    end

    test "returns 401 without auth header", %{conn: conn} do
      conn = get(conn, "/api/v1/me")
      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end

    test "returns 401 with invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid.token.here")
        |> get("/api/v1/me")

      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end

    test "returns 401 with malformed auth header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Token abc123")
        |> get("/api/v1/me")

      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end
  end
end
