defmodule ElixirApiCore.Repo.Migrations.CreateCoreIdentityTenancyAuthTables do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :display_name, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, ["lower(email)"], name: :users_email_lower_index)

    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      add :account_id, references(:accounts, on_delete: :delete_all, type: :binary_id),
        null: false

      add :role, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:memberships, [:user_id])
    create index(:memberships, [:account_id])

    create unique_index(:memberships, [:user_id, :account_id],
             name: :memberships_user_account_index
           )

    create constraint(:memberships, :memberships_role_check,
             check: "role IN ('owner', 'admin', 'member')"
           )

    create table(:identities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :provider, :string, null: false
      add :provider_uid, :string
      add :password_hash, :string

      timestamps(type: :utc_datetime)
    end

    create index(:identities, [:user_id])

    create unique_index(:identities, [:provider, :provider_uid],
             where: "provider_uid IS NOT NULL",
             name: :identities_provider_uid_index
           )

    create constraint(:identities, :identities_provider_check,
             check: "provider IN ('password', 'google')"
           )

    create constraint(:identities, :identities_password_hash_required,
             check: "provider <> 'password' OR password_hash IS NOT NULL"
           )

    create constraint(:identities, :identities_provider_uid_required,
             check: "provider = 'password' OR provider_uid IS NOT NULL"
           )

    create table(:refresh_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :token_hash, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:refresh_tokens, [:user_id])
    create index(:refresh_tokens, [:expires_at])
    create unique_index(:refresh_tokens, [:token_hash], name: :refresh_tokens_token_hash_index)
  end
end
