defmodule ElixirApiCore.Auth.RefreshToken do
  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirApiCore.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "refresh_tokens" do
    field :token_hash, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(refresh_token, attrs) do
    refresh_token
    |> cast(attrs, [:user_id, :token_hash, :expires_at, :revoked_at])
    |> validate_required([:user_id, :token_hash, :expires_at])
    |> validate_length(:token_hash, min: 32, max: 512)
    |> assoc_constraint(:user)
    |> unique_constraint(:token_hash, name: :refresh_tokens_token_hash_index)
  end
end
