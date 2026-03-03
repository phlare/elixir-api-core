defmodule ElixirApiCore.Accounts.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirApiCore.Accounts.Account
  alias ElixirApiCore.Accounts.User

  @roles [:owner, :admin, :member]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "memberships" do
    field :role, Ecto.Enum, values: @roles

    belongs_to :user, User
    belongs_to :account, Account

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :account_id, :role])
    |> validate_required([:user_id, :account_id, :role])
    |> assoc_constraint(:user)
    |> assoc_constraint(:account)
    |> unique_constraint([:user_id, :account_id], name: :memberships_user_account_index)
    |> check_constraint(:role, name: :memberships_role_check)
  end
end
