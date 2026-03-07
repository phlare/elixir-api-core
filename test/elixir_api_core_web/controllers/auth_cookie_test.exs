defmodule ElixirApiCoreWeb.AuthCookieTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  @cookie_name "_refresh_token"

  describe "cookie transport on register" do
    test "sets HttpOnly refresh token cookie", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          email: "cookie-reg@example.com",
          password: "password123!"
        })

      resp = json_response(conn, 201)
      cookie = conn.resp_cookies[@cookie_name]

      assert cookie
      assert cookie.value == resp["data"]["refresh_token"]
      assert cookie.http_only == true
      assert cookie.same_site == "Strict"
      assert cookie.path == "/api/v1/auth"
    end
  end

  describe "cookie transport on login" do
    setup %{conn: conn} do
      post(conn, "/api/v1/auth/register", %{
        email: "cookie-login@example.com",
        password: "password123!"
      })

      :ok
    end

    test "sets refresh token cookie", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/login", %{
          email: "cookie-login@example.com",
          password: "password123!"
        })

      resp = json_response(conn, 200)
      cookie = conn.resp_cookies[@cookie_name]

      assert cookie
      assert cookie.value == resp["data"]["refresh_token"]
    end
  end

  describe "cookie transport on refresh" do
    setup %{conn: conn} do
      resp =
        conn
        |> post("/api/v1/auth/register", %{
          email: "cookie-refresh@example.com",
          password: "password123!"
        })
        |> json_response(201)

      %{refresh_token: resp["data"]["refresh_token"]}
    end

    test "sets new cookie after rotation", %{conn: conn, refresh_token: rt} do
      conn = post(conn, "/api/v1/auth/refresh", %{refresh_token: rt})
      resp = json_response(conn, 200)
      cookie = conn.resp_cookies[@cookie_name]

      assert cookie.value == resp["data"]["refresh_token"]
      assert cookie.value != rt
    end

    test "reads refresh token from cookie when not in body", %{conn: conn, refresh_token: rt} do
      conn =
        conn
        |> put_req_cookie(@cookie_name, rt)
        |> post("/api/v1/auth/refresh", %{})

      resp = json_response(conn, 200)
      assert is_binary(resp["data"]["access_token"])
      assert resp["data"]["refresh_token"] != rt
    end

    test "body param takes precedence over cookie", %{conn: conn, refresh_token: rt} do
      conn =
        conn
        |> put_req_cookie(@cookie_name, "stale-cookie-value")
        |> post("/api/v1/auth/refresh", %{refresh_token: rt})

      resp = json_response(conn, 200)
      assert is_binary(resp["data"]["access_token"])
    end
  end

  describe "cookie transport on logout" do
    setup %{conn: conn} do
      resp =
        conn
        |> post("/api/v1/auth/register", %{
          email: "cookie-logout@example.com",
          password: "password123!"
        })
        |> json_response(201)

      %{refresh_token: resp["data"]["refresh_token"]}
    end

    test "clears cookie on logout", %{conn: conn, refresh_token: rt} do
      conn = post(conn, "/api/v1/auth/logout", %{refresh_token: rt})
      json_response(conn, 200)
      cookie = conn.resp_cookies[@cookie_name]

      assert cookie.value == ""
      assert cookie.max_age == 0
    end

    test "reads refresh token from cookie for logout", %{conn: conn, refresh_token: rt} do
      conn =
        conn
        |> put_req_cookie(@cookie_name, rt)
        |> post("/api/v1/auth/logout", %{})

      assert json_response(conn, 200)["data"]["status"] == "ok"
    end
  end

  describe "cookie disabled" do
    setup %{conn: conn} do
      original = Application.get_env(:elixir_api_core, ElixirApiCore.Auth.Cookie)

      Application.put_env(
        :elixir_api_core,
        ElixirApiCore.Auth.Cookie,
        Keyword.put(original, :enabled, false)
      )

      on_exit(fn ->
        Application.put_env(:elixir_api_core, ElixirApiCore.Auth.Cookie, original)
      end)

      {:ok, conn: conn}
    end

    test "does not set cookie when disabled", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          email: "no-cookie@example.com",
          password: "password123!"
        })

      json_response(conn, 201)
      refute conn.resp_cookies[@cookie_name]
    end
  end
end
