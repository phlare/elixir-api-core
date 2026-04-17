defmodule ElixirApiCoreWeb.Admin.UsersControllerTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  alias ElixirApiCore.Accounts

  describe "GET /api/v1/admin/users" do
    test "returns paginated user list for admin", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)

      conn = get(conn, "/api/v1/admin/users")
      resp = json_response(conn, 200)

      assert is_list(resp["data"]["users"])
      assert is_integer(resp["data"]["total"])
      assert resp["data"]["page"] == 1
    end

    test "excludes soft-deleted users by default", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)

      # Create and soft-delete a user
      user = ElixirApiCore.AccountsFixtures.user_fixture()
      account = ElixirApiCore.AccountsFixtures.account_fixture()

      ElixirApiCore.AccountsFixtures.membership_fixture(%{
        user: user,
        account: account,
        role: :owner
      })

      {:ok, _} = Accounts.soft_delete_user(user)

      resp = get(conn, "/api/v1/admin/users") |> json_response(200)
      user_ids = Enum.map(resp["data"]["users"], & &1["id"])
      refute user.id in user_ids
    end

    test "includes soft-deleted when include_deleted=true", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)

      user = ElixirApiCore.AccountsFixtures.user_fixture()
      account = ElixirApiCore.AccountsFixtures.account_fixture()

      ElixirApiCore.AccountsFixtures.membership_fixture(%{
        user: user,
        account: account,
        role: :owner
      })

      {:ok, _} = Accounts.soft_delete_user(user)

      resp =
        get(conn, "/api/v1/admin/users?include_deleted=true")
        |> json_response(200)

      user_ids = Enum.map(resp["data"]["users"], & &1["id"])
      assert user.id in user_ids
    end

    test "returns 403 for non-admin user", %{conn: conn} do
      conn = conn_with_token(conn)
      conn = get(conn, "/api/v1/admin/users")
      assert json_response(conn, 403)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = get(conn, "/api/v1/admin/users")
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/v1/admin/users/:id" do
    test "returns user details", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)
      user = ElixirApiCore.AccountsFixtures.user_fixture()

      resp = get(conn, "/api/v1/admin/users/#{user.id}") |> json_response(200)
      assert resp["data"]["user"]["id"] == user.id
      assert resp["data"]["user"]["email"] == user.email
    end

    test "returns 404 for non-existent user", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)
      conn = get(conn, "/api/v1/admin/users/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns 403 for non-admin", %{conn: conn} do
      conn = conn_with_token(conn)
      conn = get(conn, "/api/v1/admin/users/#{Ecto.UUID.generate()}")
      assert json_response(conn, 403)
    end
  end

  describe "DELETE /api/v1/admin/users/:id (soft delete)" do
    test "soft-deletes a user", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)
      user = ElixirApiCore.AccountsFixtures.user_fixture()
      account = ElixirApiCore.AccountsFixtures.account_fixture()

      ElixirApiCore.AccountsFixtures.membership_fixture(%{
        user: user,
        account: account,
        role: :owner
      })

      resp = delete(conn, "/api/v1/admin/users/#{user.id}") |> json_response(200)
      assert not is_nil(resp["data"]["user"]["deleted_at"])
      assert is_nil(Accounts.get_user(user.id))
    end

    test "returns 422 for already-deleted user", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)
      user = ElixirApiCore.AccountsFixtures.user_fixture()
      account = ElixirApiCore.AccountsFixtures.account_fixture()

      ElixirApiCore.AccountsFixtures.membership_fixture(%{
        user: user,
        account: account,
        role: :owner
      })

      {:ok, _} = Accounts.soft_delete_user(user)

      conn = delete(conn, "/api/v1/admin/users/#{user.id}")
      assert json_response(conn, 422)["error"]["code"] == "user_already_deleted"
    end

    test "returns 422 when trying to delete self", %{conn: conn} do
      {conn, admin} = conn_with_admin_token(conn)
      conn = delete(conn, "/api/v1/admin/users/#{admin.id}")
      assert json_response(conn, 422)["error"]["code"] == "cannot_delete_self"
    end

    test "returns 404 for non-existent user", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)
      conn = delete(conn, "/api/v1/admin/users/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/admin/users/:id/restore" do
    test "restores a soft-deleted user", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)
      user = ElixirApiCore.AccountsFixtures.user_fixture()
      account = ElixirApiCore.AccountsFixtures.account_fixture()

      ElixirApiCore.AccountsFixtures.membership_fixture(%{
        user: user,
        account: account,
        role: :owner
      })

      {:ok, _} = Accounts.soft_delete_user(user)

      resp = post(conn, "/api/v1/admin/users/#{user.id}/restore") |> json_response(200)
      assert is_nil(resp["data"]["user"]["deleted_at"])
      assert not is_nil(Accounts.get_user(user.id))
    end

    test "returns 422 for non-deleted user", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)
      user = ElixirApiCore.AccountsFixtures.user_fixture()

      conn = post(conn, "/api/v1/admin/users/#{user.id}/restore")
      assert json_response(conn, 422)["error"]["code"] == "user_not_deleted"
    end
  end

  describe "DELETE /api/v1/admin/users/:id/purge" do
    test "returns 202 and purges user (inline mode executes immediately)", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)
      user = ElixirApiCore.AccountsFixtures.user_fixture()
      account = ElixirApiCore.AccountsFixtures.account_fixture()

      ElixirApiCore.AccountsFixtures.membership_fixture(%{
        user: user,
        account: account,
        role: :owner
      })

      resp = delete(conn, "/api/v1/admin/users/#{user.id}/purge") |> json_response(202)
      assert resp["data"]["status"] == "purge_enqueued"

      # In inline mode, the worker runs immediately so user is gone
      assert is_nil(ElixirApiCore.Repo.get(ElixirApiCore.Accounts.User, user.id))
    end

    test "returns 404 for non-existent user", %{conn: conn} do
      {conn, _admin} = conn_with_admin_token(conn)
      conn = delete(conn, "/api/v1/admin/users/#{Ecto.UUID.generate()}/purge")
      assert json_response(conn, 404)
    end

    test "returns 403 for non-admin", %{conn: conn} do
      conn = conn_with_token(conn)
      conn = delete(conn, "/api/v1/admin/users/#{Ecto.UUID.generate()}/purge")
      assert json_response(conn, 403)
    end
  end
end
