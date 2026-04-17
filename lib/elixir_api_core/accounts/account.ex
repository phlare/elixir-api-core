defmodule ElixirApiCore.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirApiCore.Accounts.Membership

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "accounts" do
    field :name, :string
    field :deleted_at, :utc_datetime

    has_many :memberships, Membership
    has_many :users, through: [:memberships, :user]

    timestamps(type: :utc_datetime)
  end

  def soft_delete_changeset(account) do
    change(account, deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def restore_changeset(account) do
    change(account, deleted_at: nil)
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 160)
  end
end
