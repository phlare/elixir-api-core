defmodule ElixirApiCore.AuthTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Auth
  alias ElixirApiCore.Auth.Tokens

  describe "register/1" do
    test "creates user, account, membership, identity, and issues tokens" do
      params = %{email: "newuser@example.com", password: "password123!"}

      assert {:ok, result} = Auth.register(params)

      assert result.user.email == "newuser@example.com"
      assert result.account.name == "newuser's Account"
      assert result.membership.role == :owner
      assert result.membership.user_id == result.user.id
      assert result.membership.account_id == result.account.id
      assert is_binary(result.access_token)
      assert is_binary(result.refresh_token)

      assert {:ok, claims} = Tokens.verify_access_token(result.access_token)
      assert claims.user_id == result.user.id
      assert claims.account_id == result.account.id
      assert claims.role == "owner"

      assert :active = Tokens.refresh_token_status(result.refresh_token)
    end

    test "uses provided display_name and account_name" do
      params = %{
        email: "named@example.com",
        password: "password123!",
        display_name: "Test User",
        account_name: "My Company"
      }

      assert {:ok, result} = Auth.register(params)
      assert result.user.display_name == "Test User"
      assert result.account.name == "My Company"
    end

    test "accepts string-keyed params" do
      params = %{"email" => "stringkeys@example.com", "password" => "password123!"}

      assert {:ok, result} = Auth.register(params)
      assert result.user.email == "stringkeys@example.com"
    end

    test "returns error when email is already taken" do
      params = %{email: "dup@example.com", password: "password123!"}

      assert {:ok, _} = Auth.register(params)
      assert {:error, changeset} = Auth.register(params)
      assert %{email: [_ | _]} = errors_on(changeset)
    end

    test "returns error when email is invalid" do
      params = %{email: "notanemail", password: "password123!"}

      assert {:error, changeset} = Auth.register(params)
      assert %{email: [_ | _]} = errors_on(changeset)
    end

    test "returns error when email is missing" do
      params = %{password: "password123!"}

      assert {:error, changeset} = Auth.register(params)
      assert %{email: [_ | _]} = errors_on(changeset)
    end

    test "returns error when password is missing" do
      assert {:error, :password_required} = Auth.register(%{email: "a@b.com"})
    end

    test "returns error when password is empty" do
      assert {:error, :password_required} = Auth.register(%{email: "a@b.com", password: ""})
    end

    test "returns error when password is too short" do
      assert {:error, :password_too_short} = Auth.register(%{email: "a@b.com", password: "short"})
    end
  end

  describe "login/1" do
    setup do
      {:ok, reg} = Auth.register(%{email: "login@example.com", password: "password123!"})
      %{reg: reg}
    end

    test "authenticates user and issues tokens", %{reg: reg} do
      assert {:ok, result} = Auth.login(%{email: "login@example.com", password: "password123!"})

      assert result.user.id == reg.user.id
      assert is_binary(result.access_token)
      assert is_binary(result.refresh_token)
      assert result.active_account_id == reg.account.id
      assert result.active_role == :owner
      assert length(result.memberships) == 1

      assert {:ok, claims} = Tokens.verify_access_token(result.access_token)
      assert claims.user_id == reg.user.id
    end

    test "accepts string-keyed params" do
      assert {:ok, _} =
               Auth.login(%{"email" => "login@example.com", "password" => "password123!"})
    end

    test "returns error for wrong password" do
      assert {:error, :invalid_credentials} =
               Auth.login(%{email: "login@example.com", password: "wrongpassword"})
    end

    test "returns error for non-existent email" do
      assert {:error, :invalid_credentials} =
               Auth.login(%{email: "nobody@example.com", password: "password123!"})
    end

    test "returns error for missing password" do
      assert {:error, :invalid_credentials} =
               Auth.login(%{email: "login@example.com"})
    end

    test "returns error for missing email" do
      assert {:error, :invalid_credentials} =
               Auth.login(%{password: "password123!"})
    end

    test "is case-insensitive on email" do
      assert {:ok, _} = Auth.login(%{email: "LOGIN@example.com", password: "password123!"})
    end
  end

  describe "refresh/1" do
    setup do
      {:ok, reg} = Auth.register(%{email: "refresh@example.com", password: "password123!"})
      %{reg: reg}
    end

    test "rotates refresh token and issues new access token", %{reg: reg} do
      assert {:ok, result} = Auth.refresh(%{refresh_token: reg.refresh_token})

      assert is_binary(result.access_token)
      assert is_binary(result.refresh_token)
      assert result.refresh_token != reg.refresh_token
      assert result.account_id == reg.account.id
      assert result.role == :owner

      assert {:ok, claims} = Tokens.verify_access_token(result.access_token)
      assert claims.user_id == reg.user.id
    end

    test "returns error for invalid refresh token" do
      assert {:error, :invalid_refresh_token} = Auth.refresh(%{refresh_token: "garbage"})
    end

    test "returns error on reuse of revoked refresh token", %{reg: reg} do
      assert {:ok, _} = Auth.refresh(%{refresh_token: reg.refresh_token})

      assert {:error, :refresh_token_reuse_detected} =
               Auth.refresh(%{refresh_token: reg.refresh_token})
    end

    test "accepts explicit account_id", %{reg: reg} do
      assert {:ok, result} =
               Auth.refresh(%{
                 refresh_token: reg.refresh_token,
                 account_id: reg.account.id
               })

      assert result.account_id == reg.account.id
    end

    test "returns error for account_id user doesn't belong to", %{reg: reg} do
      other_account = account_fixture()

      assert {:error, :account_not_found} =
               Auth.refresh(%{
                 refresh_token: reg.refresh_token,
                 account_id: other_account.id
               })
    end
  end

  describe "logout/1" do
    setup do
      {:ok, reg} = Auth.register(%{email: "logout@example.com", password: "password123!"})
      %{reg: reg}
    end

    test "revokes the refresh token", %{reg: reg} do
      assert {:ok, _} = Auth.logout(%{refresh_token: reg.refresh_token})
      assert :revoked = Tokens.refresh_token_status(reg.refresh_token)
    end

    test "is idempotent — revoking twice succeeds", %{reg: reg} do
      assert {:ok, _} = Auth.logout(%{refresh_token: reg.refresh_token})
      assert {:ok, _} = Auth.logout(%{refresh_token: reg.refresh_token})
    end

    test "returns error for invalid refresh token" do
      assert {:error, :invalid_refresh_token} = Auth.logout(%{refresh_token: "garbage"})
    end

    test "returns error when refresh token is missing" do
      assert {:error, :missing_refresh_token} = Auth.logout(%{})
    end
  end

  describe "switch_account/2" do
    setup do
      {:ok, reg} = Auth.register(%{email: "switch@example.com", password: "password123!"})
      other_account = account_fixture()

      {:ok, _membership} =
        ElixirApiCore.Accounts.create_membership(%{
          user_id: reg.user.id,
          account_id: other_account.id,
          role: :admin
        })

      %{reg: reg, other_account: other_account}
    end

    test "issues new access token for the target account", %{reg: reg, other_account: other} do
      assert {:ok, result} = Auth.switch_account(reg.user.id, other.id)

      assert result.account_id == other.id
      assert result.role == :admin
      assert is_binary(result.access_token)

      assert {:ok, claims} = Tokens.verify_access_token(result.access_token)
      assert claims.account_id == other.id
      assert claims.role == "admin"
    end

    test "returns error for account user doesn't belong to", %{reg: reg} do
      fake_id = Ecto.UUID.generate()
      assert {:error, :account_not_found} = Auth.switch_account(reg.user.id, fake_id)
    end
  end
end
