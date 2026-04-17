defmodule ElixirApiCore.AuthTest do
  use ElixirApiCore.DataCase, async: true

  import ElixirApiCore.AccountsFixtures
  import Swoosh.TestAssertions

  alias ElixirApiCore.Auth
  alias ElixirApiCore.Auth.EmailToken
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

    test "returns error when password exceeds 128 characters" do
      long_password = String.duplicate("a", 129)

      assert {:error, :password_too_long} =
               Auth.register(%{email: "a@b.com", password: long_password})
    end

    test "accepts password of exactly 128 characters" do
      password = String.duplicate("a", 128)
      assert {:ok, _} = Auth.register(%{email: "max@example.com", password: password})
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

  describe "soft-deleted user rejection" do
    setup do
      {:ok, result} =
        Auth.register(%{
          email: "del-reject-#{System.unique_integer([:positive])}@example.com",
          password: "password123!"
        })

      {:ok, _} = ElixirApiCore.Accounts.soft_delete_user(result.user)
      %{email: result.user.email, refresh_token: result.refresh_token}
    end

    test "deleted user cannot login", %{email: email} do
      assert {:error, :invalid_credentials} =
               Auth.login(%{email: email, password: "password123!"})
    end

    test "deleted user cannot refresh token", %{refresh_token: token} do
      assert {:error, _reason} = Auth.refresh(%{refresh_token: token})
    end

    test "deleted user cannot login via Google OAuth" do
      uid = "google-deleted-#{System.unique_integer([:positive])}"
      user = ElixirApiCore.AccountsFixtures.user_fixture()
      account = ElixirApiCore.AccountsFixtures.account_fixture()

      ElixirApiCore.AccountsFixtures.membership_fixture(%{
        user: user,
        account: account,
        role: :owner
      })

      # Create Google identity
      %ElixirApiCore.Auth.Identity{}
      |> ElixirApiCore.Auth.Identity.changeset(%{
        user_id: user.id,
        provider: :google,
        provider_uid: uid
      })
      |> ElixirApiCore.Repo.insert!()

      # Soft-delete the user
      {:ok, _} = ElixirApiCore.Accounts.soft_delete_user(user)

      # Mock OAuth to return this user's provider_uid
      Process.put(:mock_oauth_uid, uid)

      # The login_via_identity path should reject the deleted user
      assert {:error, :invalid_credentials} =
               Auth.google_callback(%{code: "valid_code"})
    end
  end

  describe "register/1 email verification hook" do
    test "enqueues and delivers a verification email after successful registration" do
      params = %{
        email: "verify-me-#{System.unique_integer([:positive])}@example.com",
        password: "password123!"
      }

      assert {:ok, _result} = Auth.register(params)
      # Oban testing: :inline runs jobs synchronously, so the email is sent immediately
      assert_email_sent(subject: "Verify your email address", to: [{params.email, params.email}])
    end
  end

  describe "send_verification_email/1" do
    test "enqueues a verification email for an unverified user" do
      user = user_fixture()

      assert {:ok, :enqueued} = Auth.send_verification_email(user)
      assert_email_sent(subject: "Verify your email address")
    end

    test "refuses to send to an already-verified user" do
      user = user_fixture()

      {:ok, verified} =
        user |> ElixirApiCore.Accounts.User.verify_email_changeset() |> Repo.update()

      assert {:error, :email_already_verified} = Auth.send_verification_email(verified)
    end
  end

  describe "verify_email/1" do
    test "sets email_verified_at when given a valid token" do
      user = user_fixture()
      token = EmailToken.sign_verification(user.id)

      assert {:ok, verified} = Auth.verify_email(token)
      assert %DateTime{} = verified.email_verified_at
    end

    test "is idempotent on the second call (returns :email_already_verified)" do
      user = user_fixture()
      token = EmailToken.sign_verification(user.id)

      assert {:ok, _} = Auth.verify_email(token)
      assert {:error, :email_already_verified} = Auth.verify_email(token)
    end

    test "rejects an invalid token" do
      assert {:error, :invalid_email_token} = Auth.verify_email("not-a-real-token")
    end

    test "rejects a reset token used as a verification token" do
      user_id = Ecto.UUID.generate()
      reset_token = EmailToken.sign_password_reset(user_id, "fp")

      assert {:error, :invalid_email_token} = Auth.verify_email(reset_token)
    end
  end

  describe "request_password_reset/1" do
    test "enqueues a reset email when the user exists with a password identity" do
      {:ok, result} =
        Auth.register(%{
          email: "reset-me-#{System.unique_integer([:positive])}@example.com",
          password: "original123!"
        })

      # consume the verification email that registration enqueues
      assert_email_sent(subject: "Verify your email address")

      assert {:ok, :enqueued} = Auth.request_password_reset(result.user.email)
      assert_email_sent(subject: "Reset your password")
    end

    test "is :ok for a non-existent email (no enumeration)" do
      assert {:ok, :enqueued} = Auth.request_password_reset("nobody@example.com")
      assert_no_email_sent()
    end

    test "does not enqueue for a user without a password identity (Google-only)" do
      user = user_fixture()
      # no password identity created

      assert {:ok, :enqueued} = Auth.request_password_reset(user.email)
      assert_no_email_sent()
    end
  end

  describe "reset_password/2" do
    setup do
      {:ok, result} =
        Auth.register(%{
          email: "pwd-reset-#{System.unique_integer([:positive])}@example.com",
          password: "original123!"
        })

      # drain the verification email from the test mailbox
      assert_email_sent(subject: "Verify your email address")

      identity =
        Repo.get_by!(ElixirApiCore.Auth.Identity, user_id: result.user.id, provider: :password)

      %{user: result.user, identity: identity}
    end

    test "updates the password identity when the token is valid", %{
      user: user,
      identity: identity
    } do
      fingerprint = String.slice(identity.password_hash, 0, 32)
      token = EmailToken.sign_password_reset(user.id, fingerprint)

      assert {:ok, _user} = Auth.reset_password(token, "newpassword456!")

      assert {:ok, _result} =
               Auth.login(%{email: user.email, password: "newpassword456!"})

      assert {:error, :invalid_credentials} =
               Auth.login(%{email: user.email, password: "original123!"})
    end

    test "rejects a replayed token after the password was reset once", %{
      user: user,
      identity: identity
    } do
      fingerprint = String.slice(identity.password_hash, 0, 32)
      token = EmailToken.sign_password_reset(user.id, fingerprint)

      assert {:ok, _user} = Auth.reset_password(token, "newpassword456!")

      assert {:error, :invalid_email_token} =
               Auth.reset_password(token, "anotherpassword789!")
    end

    test "rejects a token signed against an older password hash", %{user: user} do
      # Simulates signing with a stale fingerprint (e.g., password was rotated
      # between email send and click).
      token = EmailToken.sign_password_reset(user.id, "stale-fingerprint-xxxxxxxxxxxxxxx")

      assert {:error, :invalid_email_token} =
               Auth.reset_password(token, "newpassword456!")
    end

    test "rejects a tampered token" do
      assert {:error, :invalid_email_token} =
               Auth.reset_password("bogus", "newpassword456!")
    end

    test "returns :no_password_identity when the user has no password" do
      user = user_fixture()
      token = EmailToken.sign_password_reset(user.id, "any-fingerprint")

      assert {:error, :no_password_identity} =
               Auth.reset_password(token, "newpassword456!")
    end

    test "validates the new password length", %{user: user, identity: identity} do
      fingerprint = String.slice(identity.password_hash, 0, 32)
      token = EmailToken.sign_password_reset(user.id, fingerprint)

      assert {:error, :password_too_short} = Auth.reset_password(token, "short")
    end
  end
end
