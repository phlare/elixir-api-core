defmodule ElixirApiCore.AuthDeleteAccountTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Auth
  alias ElixirApiCore.Auth.Identity
  alias ElixirApiCore.Audit.Event

  defp setup_password_user(_) do
    {:ok, result} =
      Auth.register(%{
        email: "delete-pw-#{System.unique_integer([:positive])}@example.com",
        password: "password123!"
      })

    %{user: result.user, account: result.account}
  end

  defp setup_oauth_user(_) do
    user = user_fixture()
    account = account_fixture()
    membership_fixture(%{user: user, account: account, role: :owner})

    # Create a Google identity (no password)
    %Identity{}
    |> Identity.changeset(%{
      user_id: user.id,
      provider: :google,
      provider_uid: "google-#{System.unique_integer([:positive])}"
    })
    |> Repo.insert!()

    %{user: user, account: account}
  end

  describe "delete_my_account/2 with password user" do
    setup :setup_password_user

    test "succeeds with correct password", %{user: user} do
      assert {:ok, :deleted} = Auth.delete_my_account(user, %{password: "password123!"})

      # User is soft-deleted
      assert is_nil(Accounts.get_user(user.id))
      assert not is_nil(Accounts.get_user_including_deleted(user.id))
    end

    test "fails with wrong password", %{user: user} do
      assert {:error, :invalid_credentials} =
               Auth.delete_my_account(user, %{password: "wrong"})

      # User is NOT deleted
      assert not is_nil(Accounts.get_user(user.id))
    end

    test "fails with missing password", %{user: user} do
      assert {:error, :invalid_credentials} = Auth.delete_my_account(user, %{})
    end
  end

  describe "delete_my_account/2 with OAuth-only user" do
    setup :setup_oauth_user

    test "succeeds with correct confirmation text", %{user: user} do
      assert {:ok, :deleted} =
               Auth.delete_my_account(user, %{confirmation_text: "delete my account"})
    end

    test "succeeds case-insensitively", %{user: user} do
      assert {:ok, :deleted} =
               Auth.delete_my_account(user, %{confirmation_text: "DELETE MY ACCOUNT"})
    end

    test "succeeds with surrounding whitespace", %{user: user} do
      assert {:ok, :deleted} =
               Auth.delete_my_account(user, %{confirmation_text: "  delete my account  "})
    end

    test "fails with wrong text", %{user: user} do
      assert {:error, :invalid_confirmation} =
               Auth.delete_my_account(user, %{confirmation_text: "delete"})
    end

    test "fails with missing confirmation", %{user: user} do
      assert {:error, :invalid_confirmation} = Auth.delete_my_account(user, %{})
    end
  end

  describe "delete_my_account/2 edge cases" do
    test "returns error for already-deleted user" do
      {:ok, result} =
        Auth.register(%{
          email: "already-del-#{System.unique_integer([:positive])}@example.com",
          password: "password123!"
        })

      {:ok, :deleted} = Auth.delete_my_account(result.user, %{password: "password123!"})

      deleted_user = Accounts.get_user_including_deleted(result.user.id)

      assert {:error, :user_already_deleted} =
               Auth.delete_my_account(deleted_user, %{password: "password123!"})
    end

    test "logs user.self_deleted audit event", %{} do
      {:ok, result} =
        Auth.register(%{
          email: "audit-del-#{System.unique_integer([:positive])}@example.com",
          password: "password123!"
        })

      {:ok, :deleted} = Auth.delete_my_account(result.user, %{password: "password123!"})

      events =
        from(e in Event,
          where: e.actor_id == ^result.user.id and e.action == "user.self_deleted"
        )
        |> Repo.all()

      assert length(events) == 1
    end
  end
end
