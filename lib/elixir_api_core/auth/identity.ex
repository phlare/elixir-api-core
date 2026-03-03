defmodule ElixirApiCore.Auth.Identity do
  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirApiCore.Accounts.User

  @providers [:password, :google]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "identities" do
    field :provider, Ecto.Enum, values: @providers
    field :provider_uid, :string
    field :password_hash, :string, redact: true

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:user_id, :provider, :provider_uid, :password_hash])
    |> validate_required([:user_id, :provider])
    |> validate_provider_requirements()
    |> assoc_constraint(:user)
    |> unique_constraint([:provider, :provider_uid],
      name: :identities_provider_uid_index,
      error_key: :provider_uid
    )
    |> check_constraint(:provider, name: :identities_provider_check)
    |> check_constraint(:password_hash, name: :identities_password_hash_required)
    |> check_constraint(:provider_uid, name: :identities_provider_uid_required)
  end

  defp validate_provider_requirements(changeset) do
    case get_field(changeset, :provider) do
      :password ->
        changeset
        |> validate_required([:password_hash])
        |> put_change(:provider_uid, nil)

      provider when provider in [:google] ->
        validate_required(changeset, [:provider_uid])

      _ ->
        changeset
    end
  end
end
