defmodule ElixirApiCoreWeb.AuthControllerTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  import ElixirApiCore.AccountsFixtures

  describe "POST /api/v1/auth/register" do
    test "creates user and returns tokens", %{conn: conn} do
      params = %{email: "new@example.com", password: "password123!"}

      conn = post(conn, "/api/v1/auth/register", params)
      resp = json_response(conn, 201)

      assert resp["data"]["user"]["email"] == "new@example.com"
      assert resp["data"]["account"]["name"] == "new's Account"
      assert is_binary(resp["data"]["access_token"])
      assert is_binary(resp["data"]["refresh_token"])
    end

    test "returns validation error for duplicate email", %{conn: conn} do
      params = %{email: "dup@example.com", password: "password123!"}
      post(conn, "/api/v1/auth/register", params)

      conn = post(conn, "/api/v1/auth/register", params)
      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "validation_error"
      assert resp["error"]["details"]["email"]
    end

    test "returns error for invalid email", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/register", %{email: "bad", password: "password123!"})
      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "validation_error"
    end

    test "returns error for missing password", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/register", %{email: "a@b.com"})
      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "password_required"
    end

    test "returns error for short password", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/register", %{email: "a@b.com", password: "short"})
      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "password_too_short"
    end
  end

  describe "POST /api/v1/auth/login" do
    setup %{conn: conn} do
      post(conn, "/api/v1/auth/register", %{email: "login@example.com", password: "password123!"})
      :ok
    end

    test "authenticates and returns tokens", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/login", %{email: "login@example.com", password: "password123!"})

      resp = json_response(conn, 200)

      assert resp["data"]["user"]["email"] == "login@example.com"
      assert is_binary(resp["data"]["access_token"])
      assert is_binary(resp["data"]["refresh_token"])
      assert is_list(resp["data"]["accounts"])
    end

    test "returns 401 for wrong password", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/login", %{email: "login@example.com", password: "wrong"})
      resp = json_response(conn, 401)
      assert resp["error"]["code"] == "invalid_credentials"
    end

    test "returns 401 for non-existent email", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/login", %{email: "nobody@example.com", password: "password123!"})

      assert json_response(conn, 401)["error"]["code"] == "invalid_credentials"
    end
  end

  describe "POST /api/v1/auth/refresh" do
    setup %{conn: conn} do
      resp =
        conn
        |> post("/api/v1/auth/register", %{email: "refresh@example.com", password: "password123!"})
        |> json_response(201)

      %{refresh_token: resp["data"]["refresh_token"]}
    end

    test "rotates refresh token", %{conn: conn, refresh_token: rt} do
      conn = post(conn, "/api/v1/auth/refresh", %{refresh_token: rt})
      resp = json_response(conn, 200)

      assert is_binary(resp["data"]["access_token"])
      assert is_binary(resp["data"]["refresh_token"])
      assert resp["data"]["refresh_token"] != rt
    end

    test "returns 401 for invalid token", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/refresh", %{refresh_token: "garbage"})
      assert json_response(conn, 401)["error"]["code"] == "invalid_refresh_token"
    end

    test "returns 401 on reuse detection", %{conn: conn, refresh_token: rt} do
      post(conn, "/api/v1/auth/refresh", %{refresh_token: rt})

      conn = post(conn, "/api/v1/auth/refresh", %{refresh_token: rt})
      assert json_response(conn, 401)["error"]["code"] == "refresh_token_reuse_detected"
    end
  end

  describe "POST /api/v1/auth/logout" do
    setup %{conn: conn} do
      resp =
        conn
        |> post("/api/v1/auth/register", %{email: "logout@example.com", password: "password123!"})
        |> json_response(201)

      %{refresh_token: resp["data"]["refresh_token"]}
    end

    test "revokes refresh token", %{conn: conn, refresh_token: rt} do
      conn = post(conn, "/api/v1/auth/logout", %{refresh_token: rt})
      assert json_response(conn, 200) == %{"data" => %{"status" => "ok"}}
    end

    test "is idempotent", %{conn: conn, refresh_token: rt} do
      post(conn, "/api/v1/auth/logout", %{refresh_token: rt})

      conn = post(conn, "/api/v1/auth/logout", %{refresh_token: rt})
      assert json_response(conn, 200)["data"]["status"] == "ok"
    end

    test "returns 401 for invalid token", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/logout", %{refresh_token: "garbage"})
      assert json_response(conn, 401)["error"]["code"] == "invalid_refresh_token"
    end
  end

  describe "POST /api/v1/auth/switch_account (authenticated)" do
    setup %{conn: conn} do
      resp =
        conn
        |> post("/api/v1/auth/register", %{email: "switch@example.com", password: "password123!"})
        |> json_response(201)

      user_id = resp["data"]["user"]["id"]
      access_token = resp["data"]["access_token"]
      other_account = account_fixture()

      {:ok, _} =
        ElixirApiCore.Accounts.create_membership(%{
          user_id: user_id,
          account_id: other_account.id,
          role: :admin
        })

      authed_conn = put_req_header(conn, "authorization", "Bearer #{access_token}")
      %{authed_conn: authed_conn, other_account: other_account}
    end

    test "issues new access token for target account", %{authed_conn: conn, other_account: other} do
      conn = post(conn, "/api/v1/auth/switch_account", %{account_id: other.id})
      resp = json_response(conn, 200)

      assert is_binary(resp["data"]["access_token"])
      assert resp["data"]["account_id"] == other.id
      assert resp["data"]["role"] == "admin"
    end

    test "returns 404 for account user doesn't belong to", %{authed_conn: conn} do
      conn = post(conn, "/api/v1/auth/switch_account", %{account_id: Ecto.UUID.generate()})
      assert json_response(conn, 404)["error"]["code"] == "account_not_found"
    end

    test "returns 401 without auth header", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/switch_account", %{account_id: Ecto.UUID.generate()})
      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end
  end
end
