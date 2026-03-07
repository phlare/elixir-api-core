defmodule ElixirApiCore.Repo.Migrations.CreateAuditEvents do
  use Ecto.Migration

  def change do
    create table(:audit_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :actor_id, :binary_id
      add :account_id, :binary_id
      add :resource_type, :string
      add :resource_id, :binary_id
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_events, [:actor_id])
    create index(:audit_events, [:account_id])
    create index(:audit_events, [:action])
    create index(:audit_events, [:inserted_at])
  end
end
