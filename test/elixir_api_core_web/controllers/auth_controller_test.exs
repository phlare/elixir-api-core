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

    test "returns error for password exceeding 128 characters", %{conn: conn} do
      long_password = String.duplicate("a", 129)
      conn = post(conn, "/api/v1/auth/register", %{email: "a@b.com", password: long_password})
      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "password_too_long"
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

  describe "POST /api/v1/auth/verify_email" do
    test "returns ok for a valid token", %{conn: conn} do
      user = user_fixture()
      token = ElixirApiCore.Auth.EmailToken.sign_verification(user.id)

      conn = post(conn, "/api/v1/auth/verify_email", %{token: token})

      assert json_response(conn, 200)["data"]["status"] == "ok"
    end

    test "is idempotent — re-verifying a verified user returns ok", %{conn: conn} do
      user = user_fixture()
      token = ElixirApiCore.Auth.EmailToken.sign_verification(user.id)

      conn1 = post(conn, "/api/v1/auth/verify_email", %{token: token})
      assert json_response(conn1, 200)["data"]["status"] == "ok"

      conn2 = post(build_conn(), "/api/v1/auth/verify_email", %{token: token})
      assert json_response(conn2, 200)["data"]["status"] == "ok"
    end

    test "returns 400 for an invalid token", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/verify_email", %{token: "garbage"})
      assert json_response(conn, 400)["error"]["code"] == "invalid_email_token"
    end

    test "returns 400 when token is missing", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/verify_email", %{})
      assert json_response(conn, 400)["error"]["code"] == "invalid_email_token"
    end
  end

  describe "POST /api/v1/auth/send_verification (authenticated)" do
    setup %{conn: conn} do
      resp =
        conn
        |> post("/api/v1/auth/register", %{
          email: "send-verif-#{System.unique_integer([:positive])}@example.com",
          password: "password123!"
        })
        |> json_response(201)

      authed_conn =
        put_req_header(conn, "authorization", "Bearer #{resp["data"]["access_token"]}")

      %{authed_conn: authed_conn}
    end

    test "returns ok and triggers a verification email", %{authed_conn: conn} do
      conn = post(conn, "/api/v1/auth/send_verification", %{})
      assert json_response(conn, 200)["data"]["status"] == "ok"
    end

    test "returns 401 without auth header", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/send_verification", %{})
      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end
  end

  describe "POST /api/v1/auth/request_password_reset" do
    test "returns ok for an existing email", %{conn: conn} do
      email = "pwreset-#{System.unique_integer([:positive])}@example.com"

      post(conn, "/api/v1/auth/register", %{email: email, password: "password123!"})

      conn = post(conn, "/api/v1/auth/request_password_reset", %{email: email})
      assert json_response(conn, 200)["data"]["status"] == "ok"
    end

    test "returns ok for a non-existent email (no enumeration)", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/request_password_reset", %{email: "nobody@example.com"})
      assert json_response(conn, 200)["data"]["status"] == "ok"
    end

    test "returns ok for a missing email param", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/request_password_reset", %{})
      assert json_response(conn, 200)["data"]["status"] == "ok"
    end

    test "counts whitespace/case variants against the same rate-limit bucket", %{conn: conn} do
      email = "rate-#{System.unique_integer([:positive])}@example.com"
      # limit is 3 per 300s; send 3 semantically identical requests to exhaust the bucket
      for variant <- [email, "  #{email}", String.upcase(email)] do
        post(conn, "/api/v1/auth/request_password_reset", %{email: variant})
      end

      # 4th identical request — should be rate-limited
      conn = post(conn, "/api/v1/auth/request_password_reset", %{email: email})
      assert json_response(conn, 429)["error"]["code"] == "rate_limited"
    end
  end

  describe "POST /api/v1/auth/reset_password" do
    setup %{conn: conn} do
      email = "reset-ctrl-#{System.unique_integer([:positive])}@example.com"

      resp =
        conn
        |> post("/api/v1/auth/register", %{email: email, password: "original123!"})
        |> json_response(201)

      user_id = resp["data"]["user"]["id"]

      identity =
        ElixirApiCore.Repo.get_by!(ElixirApiCore.Auth.Identity,
          user_id: user_id,
          provider: :password
        )

      fingerprint = String.slice(identity.password_hash, 0, 32)
      token = ElixirApiCore.Auth.EmailToken.sign_password_reset(user_id, fingerprint)

      %{email: email, token: token, user_id: user_id}
    end

    test "updates password and allows login with the new credential", %{
      conn: conn,
      email: email,
      token: token
    } do
      conn =
        post(conn, "/api/v1/auth/reset_password", %{token: token, password: "newpassword456!"})

      assert json_response(conn, 200)["data"]["status"] == "ok"

      conn =
        build_conn()
        |> post("/api/v1/auth/login", %{email: email, password: "newpassword456!"})

      assert json_response(conn, 200)["data"]["access_token"]
    end

    test "returns 400 for a tampered token", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/reset_password", %{token: "bogus", password: "newpassword456!"})

      assert json_response(conn, 400)["error"]["code"] == "invalid_email_token"
    end

    test "returns 422 when the new password is too short", %{conn: conn, token: token} do
      conn = post(conn, "/api/v1/auth/reset_password", %{token: token, password: "short"})

      assert json_response(conn, 422)["error"]["code"] == "password_too_short"
    end

    test "returns 400 when the token is missing", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/reset_password", %{password: "newpassword456!"})
      assert json_response(conn, 400)["error"]["code"] == "invalid_email_token"
    end
  end
end
