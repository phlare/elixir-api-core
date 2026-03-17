defmodule ElixirApiCoreWeb.GoogleOAuthControllerTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  describe "GET /api/v1/auth/google/start" do
    test "returns authorize URL and sets state cookie", %{conn: conn} do
      conn = get(conn, "/api/v1/auth/google/start")
      resp = json_response(conn, 200)

      assert resp["data"]["authorize_url"] =~ "https://mock.oauth.example.com/authorize"
      assert conn.resp_cookies["_oauth_state"]
    end
  end

  describe "GET /api/v1/auth/google/callback" do
    setup %{conn: conn} do
      # Start the OAuth flow to get a state cookie
      start_conn = get(conn, "/api/v1/auth/google/start")
      resp = json_response(start_conn, 200)

      # Extract state from the authorize URL
      %URI{query: query} = URI.parse(resp["data"]["authorize_url"])
      %{"state" => state} = URI.decode_query(query)

      # Recycle conn to carry cookies forward
      conn = recycle(start_conn)

      %{conn: conn, state: state}
    end

    test "creates new user and returns 201 with tokens", %{conn: conn, state: state} do
      conn = get(conn, "/api/v1/auth/google/callback", %{code: "valid_code", state: state})
      resp = json_response(conn, 201)

      assert resp["data"]["user"]["email"] == "google@example.com"
      assert resp["data"]["account"]["name"] == "google's Account"
      assert is_binary(resp["data"]["access_token"])
      assert is_binary(resp["data"]["refresh_token"])
    end

    test "logs in existing google user and returns 200", %{conn: conn, state: state} do
      # First call creates the user
      first_conn = get(conn, "/api/v1/auth/google/callback", %{code: "valid_code", state: state})
      assert json_response(first_conn, 201)

      # Start a new OAuth flow for the second callback
      second_start = get(recycle(first_conn), "/api/v1/auth/google/start")
      resp = json_response(second_start, 200)
      %URI{query: query} = URI.parse(resp["data"]["authorize_url"])
      %{"state" => state2} = URI.decode_query(query)

      conn2 = recycle(second_start)
      conn2 = get(conn2, "/api/v1/auth/google/callback", %{code: "valid_code", state: state2})
      resp = json_response(conn2, 200)

      assert resp["data"]["user"]["email"] == "google@example.com"
      assert is_binary(resp["data"]["access_token"])
      assert is_binary(resp["data"]["refresh_token"])
      refute Map.has_key?(resp["data"], "account")
    end

    test "returns 502 for invalid authorization code", %{conn: conn, state: state} do
      conn = get(conn, "/api/v1/auth/google/callback", %{code: "invalid_code", state: state})
      resp = json_response(conn, 502)

      assert resp["error"]["code"] == "oauth_exchange_failed"
    end
  end

  describe "GET /api/v1/auth/google/callback — state validation" do
    test "returns 403 when state param is missing", %{conn: conn} do
      start_conn = get(conn, "/api/v1/auth/google/start")
      assert json_response(start_conn, 200)

      conn = recycle(start_conn)
      conn = get(conn, "/api/v1/auth/google/callback", %{code: "valid_code"})
      resp = json_response(conn, 403)

      assert resp["error"]["code"] == "invalid_oauth_state"
    end

    test "returns 403 when state param does not match cookie", %{conn: conn} do
      start_conn = get(conn, "/api/v1/auth/google/start")
      assert json_response(start_conn, 200)

      conn = recycle(start_conn)
      conn = get(conn, "/api/v1/auth/google/callback", %{code: "valid_code", state: "wrong_state"})
      resp = json_response(conn, 403)

      assert resp["error"]["code"] == "invalid_oauth_state"
    end

    test "returns 403 when state cookie is missing", %{conn: conn} do
      conn = get(conn, "/api/v1/auth/google/callback", %{code: "valid_code", state: "some_state"})
      resp = json_response(conn, 403)

      assert resp["error"]["code"] == "invalid_oauth_state"
    end
  end
end
