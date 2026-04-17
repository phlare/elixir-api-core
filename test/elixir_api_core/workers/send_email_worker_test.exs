defmodule ElixirApiCore.Workers.SendEmailWorkerTest do
  use ElixirApiCore.DataCase, async: true

  import ElixirApiCore.AccountsFixtures
  import Swoosh.TestAssertions

  alias ElixirApiCore.Workers.SendEmailWorker

  test "delivers a verification email for a real user" do
    user = user_fixture()

    assert :ok =
             perform_job(SendEmailWorker, %{
               "template" => "verification_email",
               "user_id" => user.id,
               "args" => %{"token" => "t"}
             })

    assert_email_sent(subject: "Verify your email address", to: [{user.email, user.email}])
  end

  test "delivers a password reset email for a real user" do
    user = user_fixture()

    assert :ok =
             perform_job(SendEmailWorker, %{
               "template" => "password_reset_email",
               "user_id" => user.id,
               "args" => %{"token" => "t"}
             })

    assert_email_sent(subject: "Reset your password")
  end

  test "discards when the user no longer exists" do
    assert {:discard, :user_not_found} =
             perform_job(SendEmailWorker, %{
               "template" => "verification_email",
               "user_id" => Ecto.UUID.generate(),
               "args" => %{"token" => "t"}
             })
  end
end
