defmodule ElixirApiCoreWeb.Plugs.SecurityHeadersTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  describe "security headers on public auth endpoints" do
    test "POST /auth/register sets security headers", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/register", %{email: "sh@example.com", password: "password123!"})

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end

    test "POST /auth/login sets security headers", %{conn: conn} do
      post(conn, "/api/v1/auth/register", %{email: "sh2@example.com", password: "password123!"})

      conn = post(conn, "/api/v1/auth/login", %{email: "sh2@example.com", password: "password123!"})

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end

    test "POST /auth/login sets security headers even on failure", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/login", %{email: "nope@example.com", password: "wrong"})

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end
  end

  describe "security headers on authenticated auth endpoints" do
    test "POST /auth/switch_account sets security headers", %{conn: conn} do
      conn_resp = post(conn, "/api/v1/auth/register", %{email: "sh3@example.com", password: "password123!"})
      %{"data" => %{"access_token" => token, "account" => %{"id" => account_id}}} = json_response(conn_resp, 201)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/v1/auth/switch_account", %{account_id: account_id})

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end
  end

  describe "health endpoints do NOT get security headers" do
    test "GET /healthz does not set security headers", %{conn: conn} do
      conn = get(conn, "/healthz")

      assert get_resp_header(conn, "x-content-type-options") == []
      assert get_resp_header(conn, "cache-control") != ["no-store"]
    end
  end
end
