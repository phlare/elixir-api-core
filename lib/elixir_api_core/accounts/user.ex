defmodule ElixirApiCore.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirApiCore.Accounts.Membership
  alias ElixirApiCore.Auth.Identity
  alias ElixirApiCore.Auth.RefreshToken

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :display_name, :string

    has_many :memberships, Membership
    has_many :accounts, through: [:memberships, :account]
    has_many :identities, Identity
    has_many :refresh_tokens, RefreshToken

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :display_name])
    |> normalize_email()
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 320)
    |> validate_length(:display_name, max: 160)
    |> unique_constraint(:email, name: :users_email_lower_index)
  end

  defp normalize_email(changeset) do
    update_change(changeset, :email, fn email ->
      email
      |> String.trim()
      |> String.downcase()
    end)
  end
end
