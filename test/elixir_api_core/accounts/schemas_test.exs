defmodule ElixirApiCore.Accounts.SchemasTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Accounts.Membership
  alias ElixirApiCore.Accounts.User
  alias ElixirApiCore.Auth.Identity
  alias ElixirApiCore.Auth.RefreshToken

  describe "users" do
    test "normalizes email to lowercase" do
      changeset = User.changeset(%User{}, %{email: "  USER@Example.com "})
      assert get_change(changeset, :email) == "user@example.com"
    end

    test "enforces case-insensitive unique emails" do
      assert {:ok, _user} = Accounts.create_user(%{email: "Owner@Example.com"})

      assert {:error, changeset} = Accounts.create_user(%{email: "owner@example.com"})
      assert "has already been taken" in errors_on(changeset).email
    end
  end

  describe "memberships" do
    test "requires a valid role enum value" do
      changeset =
        Membership.changeset(%Membership{}, %{
          user_id: Ecto.UUID.generate(),
          account_id: Ecto.UUID.generate(),
          role: :invalid_role
        })

      assert "is invalid" in errors_on(changeset).role
    end

    test "enforces unique account membership per user" do
      account = account_fixture()
      user = user_fixture()

      assert {:ok, _membership} =
               Accounts.create_membership(%{
                 account_id: account.id,
                 user_id: user.id,
                 role: :owner
               })

      assert {:error, changeset} =
               Accounts.create_membership(%{
                 account_id: account.id,
                 user_id: user.id,
                 role: :member
               })

      assert "has already been taken" in errors_on(changeset).user_id
    end
  end

  describe "identities" do
    test "requires password hash for password provider" do
      changeset =
        Identity.changeset(%Identity{}, %{
          user_id: Ecto.UUID.generate(),
          provider: :password
        })

      assert "can't be blank" in errors_on(changeset).password_hash
    end

    test "requires provider uid for google provider" do
      changeset =
        Identity.changeset(%Identity{}, %{
          user_id: Ecto.UUID.generate(),
          provider: :google
        })

      assert "can't be blank" in errors_on(changeset).provider_uid
    end

    test "enforces unique provider uid per provider" do
      user = user_fixture()

      identity_fixture(%{
        user: user,
        provider: :google,
        provider_uid: "google-sub-123",
        password_hash: nil
      })

      other_user = user_fixture()

      changeset =
        Identity.changeset(%Identity{}, %{
          user_id: other_user.id,
          provider: :google,
          provider_uid: "google-sub-123"
        })

      assert {:error, changeset} = Repo.insert(changeset)
      assert "has already been taken" in errors_on(changeset).provider_uid
    end
  end

  describe "refresh tokens" do
    test "requires token hash and expiration" do
      changeset =
        RefreshToken.changeset(%RefreshToken{}, %{
          user_id: Ecto.UUID.generate(),
          token_hash: "short"
        })

      assert "can't be blank" in errors_on(changeset).expires_at
      assert "should be at least 32 character(s)" in errors_on(changeset).token_hash
    end

    test "enforces unique token hashes" do
      user = user_fixture()
      refresh_token_fixture(%{user: user, token_hash: String.duplicate("b", 64)})

      changeset =
        RefreshToken.changeset(%RefreshToken{}, %{
          user_id: user.id,
          token_hash: String.duplicate("b", 64),
          expires_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(86_400)
        })

      assert {:error, changeset} = Repo.insert(changeset)
      assert "has already been taken" in errors_on(changeset).token_hash
    end
  end
end
