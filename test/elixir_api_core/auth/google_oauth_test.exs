defmodule ElixirApiCore.Auth.GoogleOAuthTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Auth

  import ElixirApiCore.AccountsFixtures

  describe "google_authorize_url/0" do
    test "returns an authorize URL" do
      assert {:ok, url} = Auth.google_authorize_url()
      assert url =~ "https://mock.oauth.example.com/authorize?state="
    end
  end

  describe "google_callback/1 — new user" do
    test "creates user, account, membership, identity, and issues tokens" do
      assert {:ok, result} = Auth.google_callback(%{code: "valid_code"})

      assert result.user.email == "google@example.com"
      assert result.account.name == "google's Account"
      assert result.membership.role == :owner
      assert is_binary(result.access_token)
      assert is_binary(result.refresh_token)
    end

    test "emits user.registered_via_google audit event" do
      {:ok, result} = Auth.google_callback(%{code: "valid_code"})

      event = Repo.get_by!(ElixirApiCore.Audit.Event, action: "user.registered_via_google")
      assert event.actor_id == result.user.id
      assert event.account_id == result.account.id
    end
  end

  describe "google_callback/1 — existing user by email (link)" do
    setup do
      user = user_fixture(%{email: "google@example.com"})
      account = account_fixture()
      membership = membership_fixture(%{user: user, account: account, role: :owner})
      %{user: user, account: account, membership: membership}
    end

    test "links google identity and logs in", %{user: user} do
      assert {:ok, result} = Auth.google_callback(%{code: "valid_code"})

      assert result.user.id == user.id
      refute Map.has_key?(result, :account)
      assert is_binary(result.access_token)
      assert is_binary(result.refresh_token)
    end

    test "emits user.linked_google audit event", %{user: user} do
      {:ok, _result} = Auth.google_callback(%{code: "valid_code"})

      event = Repo.get_by!(ElixirApiCore.Audit.Event, action: "user.linked_google")
      assert event.actor_id == user.id
    end
  end

  describe "google_callback/1 — existing google identity (login)" do
    setup do
      user = user_fixture(%{email: "existing_google@example.com"})
      account = account_fixture()
      _membership = membership_fixture(%{user: user, account: account, role: :owner})

      identity_fixture(%{
        user: user,
        provider: :google,
        provider_uid: "google-uid-123",
        password_hash: nil
      })

      Process.put(:mock_oauth_email, "existing_google@example.com")
      Process.put(:mock_oauth_uid, "google-uid-123")

      on_exit(fn ->
        Process.delete(:mock_oauth_email)
        Process.delete(:mock_oauth_uid)
      end)

      %{user: user, account: account}
    end

    test "logs in without creating new identity", %{user: user} do
      assert {:ok, result} = Auth.google_callback(%{code: "valid_code"})

      assert result.user.id == user.id
      refute Map.has_key?(result, :account)
      assert is_binary(result.access_token)
      assert is_binary(result.refresh_token)
    end

    test "emits user.logged_in_via_google audit event", %{user: user} do
      {:ok, _result} = Auth.google_callback(%{code: "valid_code"})

      event = Repo.get_by!(ElixirApiCore.Audit.Event, action: "user.logged_in_via_google")
      assert event.actor_id == user.id
    end
  end

  describe "google_callback/1 — errors" do
    test "returns error for invalid code" do
      assert {:error, {:token_exchange_failed, 401}} =
               Auth.google_callback(%{code: "invalid_code"})
    end

    test "returns error for missing code" do
      assert {:error, {:token_exchange_failed, 400}} =
               Auth.google_callback(%{code: nil})
    end

    test "accepts string-keyed params" do
      assert {:ok, _result} = Auth.google_callback(%{"code" => "valid_code"})
    end
  end
end
