defmodule ElixirApiCoreWeb.UserControllerDeleteTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Auth

  describe "DELETE /api/v1/me" do
    test "returns 204 with correct password for password user", %{conn: conn} do
      {:ok, result} =
        Auth.register(%{
          email: "del-pw-#{System.unique_integer([:positive])}@example.com",
          password: "password123!"
        })

      conn =
        conn
        |> conn_with_token(membership: result.membership)
        |> delete("/api/v1/me", %{password: "password123!"})

      assert response(conn, 204)
      assert is_nil(Accounts.get_user(result.user.id))
    end

    test "returns 204 with correct confirmation text for OAuth-only user", %{conn: conn} do
      user = ElixirApiCore.AccountsFixtures.user_fixture()
      account = ElixirApiCore.AccountsFixtures.account_fixture()

      membership =
        ElixirApiCore.AccountsFixtures.membership_fixture(%{
          user: user,
          account: account,
          role: :owner
        })

      # Create Google identity only (no password)
      %ElixirApiCore.Auth.Identity{}
      |> ElixirApiCore.Auth.Identity.changeset(%{
        user_id: user.id,
        provider: :google,
        provider_uid: "google-#{System.unique_integer([:positive])}"
      })
      |> ElixirApiCore.Repo.insert!()

      conn =
        conn
        |> conn_with_token(membership: membership)
        |> delete("/api/v1/me", %{confirmation_text: "delete my account"})

      assert response(conn, 204)
      assert is_nil(Accounts.get_user(user.id))
    end

    test "returns 422 with wrong password", %{conn: conn} do
      {:ok, result} =
        Auth.register(%{
          email: "del-wrong-#{System.unique_integer([:positive])}@example.com",
          password: "password123!"
        })

      conn =
        conn
        |> conn_with_token(membership: result.membership)
        |> delete("/api/v1/me", %{password: "wrong"})

      resp = json_response(conn, 401)
      assert resp["error"]["code"] == "invalid_credentials"
    end

    test "returns 401 without auth token", %{conn: conn} do
      conn = delete(conn, "/api/v1/me", %{password: "whatever"})
      assert json_response(conn, 401)
    end

    test "returns 401 after deletion when accessing GET /me", %{conn: conn} do
      {:ok, result} =
        Auth.register(%{
          email: "del-then-me-#{System.unique_integer([:positive])}@example.com",
          password: "password123!"
        })

      authed_conn = conn_with_token(conn, membership: result.membership)

      # Delete the account
      delete(authed_conn, "/api/v1/me", %{password: "password123!"})
      |> response(204)

      # Try to access GET /me with the same token
      conn =
        conn
        |> conn_with_token(membership: result.membership)
        |> get("/api/v1/me")

      assert json_response(conn, 401)
    end
  end
end
