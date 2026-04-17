defmodule ElixirApiCore.Auth.EmailTokenTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Auth.EmailToken

  describe "verification tokens" do
    test "sign + verify roundtrip returns the user id" do
      user_id = Ecto.UUID.generate()
      token = EmailToken.sign_verification(user_id)

      assert {:ok, ^user_id} = EmailToken.verify_verification(token)
    end

    test "rejects a tampered token as invalid" do
      user_id = Ecto.UUID.generate()
      token = EmailToken.sign_verification(user_id) <> "garbage"

      assert {:error, :invalid_email_token} = EmailToken.verify_verification(token)
    end

    test "rejects a non-binary token" do
      assert {:error, :invalid_email_token} = EmailToken.verify_verification(nil)
      assert {:error, :invalid_email_token} = EmailToken.verify_verification(123)
    end

    test "rejects an expired token (signed far enough in the past to exceed TTL)" do
      user_id = Ecto.UUID.generate()
      endpoint = ElixirApiCoreWeb.Endpoint
      # signed_at is in seconds; TTL defaults to 86_400s (24h). Sign 2 days ago.
      signed_at = System.system_time(:second) - 2 * 86_400

      token =
        Phoenix.Token.sign(endpoint, "email verification", user_id, signed_at: signed_at)

      assert {:error, :expired_email_token} = EmailToken.verify_verification(token)
    end
  end

  describe "password reset tokens" do
    test "sign + verify roundtrip returns the user id" do
      user_id = Ecto.UUID.generate()
      token = EmailToken.sign_password_reset(user_id, "abc123")

      assert {:ok, %{user_id: ^user_id, fingerprint: "abc123"}} =
               EmailToken.verify_password_reset(token)
    end

    test "rejects a non-binary token" do
      assert {:error, :invalid_email_token} = EmailToken.verify_password_reset(nil)
    end
  end

  describe "salt separation" do
    test "verification token cannot be used as a reset token" do
      user_id = Ecto.UUID.generate()
      verification_token = EmailToken.sign_verification(user_id)

      assert {:error, :invalid_email_token} =
               EmailToken.verify_password_reset(verification_token)
    end

    test "reset token cannot be used as a verification token" do
      user_id = Ecto.UUID.generate()
      reset_token = EmailToken.sign_password_reset(user_id, "fp")

      assert {:error, :invalid_email_token} = EmailToken.verify_verification(reset_token)
    end
  end
end
