defmodule ElixirApiCoreWeb.AuthRateLimitTest do
  use ElixirApiCoreWeb.ConnCase, async: false

  alias ElixirApiCore.Auth.RateLimiter

  setup do
    RateLimiter.reset()
    :ok
  end

  describe "POST /api/v1/auth/login rate limiting" do
    setup %{conn: conn} do
      post(conn, "/api/v1/auth/register", %{email: "rl@example.com", password: "password123!"})
      :ok
    end

    test "returns 429 after exceeding login limit", %{conn: conn} do
      params = %{email: "rl@example.com", password: "password123!"}

      # Exhaust the 5-request limit
      for _ <- 1..5 do
        post(conn, "/api/v1/auth/login", params)
      end

      # 6th request should be rate limited
      conn = post(conn, "/api/v1/auth/login", params)
      resp = json_response(conn, 429)

      assert resp["error"]["code"] == "rate_limited"
      assert get_resp_header(conn, "retry-after") |> hd() |> String.to_integer() > 0
    end
  end

  describe "POST /api/v1/auth/refresh rate limiting" do
    test "returns 429 after exceeding refresh limit", %{conn: conn} do
      conn_resp =
        post(conn, "/api/v1/auth/register", %{email: "rl2@example.com", password: "password123!"})

      %{"data" => %{"refresh_token" => _token}} = json_response(conn_resp, 201)

      # Exhaust the 10-request refresh limit (all will fail with invalid token, but rate limit still counts)
      for _ <- 1..10 do
        post(conn, "/api/v1/auth/refresh", %{refresh_token: "bogus_token"})
      end

      # 11th request should be rate limited
      conn = post(conn, "/api/v1/auth/refresh", %{refresh_token: "bogus_token"})
      resp = json_response(conn, 429)

      assert resp["error"]["code"] == "rate_limited"
    end
  end
end
