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

  def changeset(refresh_token, attrs, opts \\ []) do
    refresh_token
    |> cast(attrs, [:user_id, :token_hash, :expires_at, :revoked_at])
    |> validate_required([:user_id, :token_hash, :expires_at])
    |> validate_length(:token_hash, is: 64)
    |> validate_expires_at_in_future(opts)
    |> assoc_constraint(:user)
    |> unique_constraint(:token_hash, name: :refresh_tokens_token_hash_index)
  end

  defp validate_expires_at_in_future(changeset, opts) do
    now =
      opts
      |> Keyword.get(:now, DateTime.utc_now())
      |> DateTime.truncate(:second)

    validate_change(changeset, :expires_at, fn :expires_at, expires_at ->
      if DateTime.compare(expires_at, now) == :gt do
        []
      else
        [expires_at: "must be in the future"]
      end
    end)
  end
end
