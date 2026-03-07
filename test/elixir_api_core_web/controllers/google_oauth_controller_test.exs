defmodule ElixirApiCoreWeb.GoogleOAuthControllerTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  describe "GET /api/v1/auth/google/start" do
    test "returns authorize URL", %{conn: conn} do
      conn = get(conn, "/api/v1/auth/google/start")
      resp = json_response(conn, 200)

      assert resp["data"]["authorize_url"] =~ "https://mock.oauth.example.com/authorize"
    end
  end

  describe "GET /api/v1/auth/google/callback" do
    test "creates new user and returns 201 with tokens", %{conn: conn} do
      conn = get(conn, "/api/v1/auth/google/callback", %{code: "valid_code"})
      resp = json_response(conn, 201)

      assert resp["data"]["user"]["email"] == "google@example.com"
      assert resp["data"]["account"]["name"] == "google's Account"
      assert is_binary(resp["data"]["access_token"])
      assert is_binary(resp["data"]["refresh_token"])
    end

    test "logs in existing google user and returns 200", %{conn: conn} do
      # First call creates the user
      get(conn, "/api/v1/auth/google/callback", %{code: "valid_code"})

      # Second call should log in (identity already exists)
      conn = get(conn, "/api/v1/auth/google/callback", %{code: "valid_code"})
      resp = json_response(conn, 200)

      assert resp["data"]["user"]["email"] == "google@example.com"
      assert is_binary(resp["data"]["access_token"])
      assert is_binary(resp["data"]["refresh_token"])
      refute Map.has_key?(resp["data"], "account")
    end

    test "returns 502 for invalid authorization code", %{conn: conn} do
      conn = get(conn, "/api/v1/auth/google/callback", %{code: "invalid_code"})
      resp = json_response(conn, 502)

      assert resp["error"]["code"] == "oauth_exchange_failed"
    end
  end
end
