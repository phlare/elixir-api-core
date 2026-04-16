defmodule ElixirApiCore.AccountsFixtures do
  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Auth.Identity
  alias ElixirApiCore.Auth.Password
  alias ElixirApiCore.Auth.RefreshToken
  alias ElixirApiCore.Repo

  def unique_email, do: "user#{System.unique_integer([:positive])}@example.com"
  def unique_name(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  def user_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{email: unique_email()})

    {:ok, user} = Accounts.create_user(attrs)
    user
  end

  def account_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: unique_name("account")})

    {:ok, account} = Accounts.create_account(attrs)
    account
  end

  def membership_fixture(attrs \\ %{}) do
    account = Map.get_lazy(attrs, :account, &account_fixture/0)
    user = Map.get_lazy(attrs, :user, &user_fixture/0)

    attrs =
      attrs
      |> Map.delete(:account)
      |> Map.delete(:user)
      |> Map.put_new(:account_id, account.id)
      |> Map.put_new(:user_id, user.id)
      |> Map.put_new(:role, :owner)

    {:ok, membership} = Accounts.create_membership(attrs)
    membership
  end

  def identity_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, &user_fixture/0)

    attrs =
      attrs
      |> Map.delete(:user)
      |> Map.put_new(:user_id, user.id)
      |> Map.put_new(:provider, :password)
      |> Map.put_new_lazy(:password_hash, fn -> Password.hash_password("password123!") end)

    %Identity{}
    |> Identity.changeset(attrs)
    |> Repo.insert!()
  end

  def system_admin_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)

    user
    |> Ecto.Changeset.change(%{is_system_admin: true})
    |> Repo.update!()
  end

  def refresh_token_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, &user_fixture/0)

    attrs =
      attrs
      |> Map.delete(:user)
      |> Map.put_new(:user_id, user.id)
      |> Map.put_new(:token_hash, String.duplicate("a", 64))
      |> Map.put_new(
        :expires_at,
        DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(86_400)
      )

    %RefreshToken{}
    |> RefreshToken.changeset(attrs)
    |> Repo.insert!()
  end
end
