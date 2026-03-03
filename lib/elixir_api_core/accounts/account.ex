defmodule ElixirApiCore.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirApiCore.Accounts.Membership

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "accounts" do
    field :name, :string

    has_many :memberships, Membership
    has_many :users, through: [:memberships, :user]

    timestamps(type: :utc_datetime)
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 160)
  end
end
