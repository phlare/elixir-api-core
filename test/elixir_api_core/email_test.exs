defmodule ElixirApiCore.EmailTest do
  use ElixirApiCore.DataCase, async: true

  import ElixirApiCore.AccountsFixtures

  alias ElixirApiCore.Email

  describe "verification_email/2" do
    test "builds a Swoosh.Email with the expected fields" do
      user = user_fixture(%{display_name: "Jane Doe"})
      token = "verification-token-123"

      email = Email.verification_email(user, token)

      assert email.subject == "Verify your email address"
      assert email.from == {"", "noreply@test.local"}
      assert email.to == [{"Jane Doe", user.email}]
      assert email.text_body =~ "Hi Jane Doe"

      expected_base = ElixirApiCoreWeb.Endpoint.url()

      assert email.text_body =~
               expected_base <>
                 "/api/v1/auth/verify_email?token=verification-token-123"
    end

    test "URL-encodes tokens with special characters" do
      user = user_fixture()
      token = "abc/def+ghi=="

      email = Email.verification_email(user, token)

      assert email.text_body =~ "token=abc%2Fdef%2Bghi%3D%3D"
    end

    test "falls back to email for to-name when display_name is nil" do
      user = user_fixture()
      email = Email.verification_email(user, "t")

      assert email.to == [{user.email, user.email}]
      refute email.text_body =~ "Hi "
      assert email.text_body =~ "Hi,"
    end
  end

  describe "password_reset_email/2" do
    test "builds a reset email with a frontend link" do
      user = user_fixture(%{display_name: "Jane Doe"})
      token = "reset-token-456"

      email = Email.password_reset_email(user, token)

      assert email.subject == "Reset your password"
      assert email.from == {"", "noreply@test.local"}
      assert email.to == [{"Jane Doe", user.email}]
      assert email.text_body =~ "Hi Jane Doe"

      assert email.text_body =~
               "http://app.test.local/reset-password?token=reset-token-456"
    end
  end

  describe "render/3 dispatch" do
    test "dispatches verification_email template" do
      user = user_fixture()
      email = Email.render("verification_email", user, %{"token" => "t1"})

      assert email.subject == "Verify your email address"
    end

    test "dispatches password_reset_email template" do
      user = user_fixture()
      email = Email.render("password_reset_email", user, %{"token" => "t2"})

      assert email.subject == "Reset your password"
    end
  end
end
