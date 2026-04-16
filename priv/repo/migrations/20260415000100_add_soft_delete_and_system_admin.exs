defmodule ElixirApiCore.Repo.Migrations.AddSoftDeleteAndSystemAdmin do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :deleted_at, :utc_datetime
      add :is_system_admin, :boolean, default: false, null: false
    end

    alter table(:accounts) do
      add :deleted_at, :utc_datetime
    end

    create index(:users, [:deleted_at], where: "deleted_at IS NOT NULL")
    create index(:accounts, [:deleted_at], where: "deleted_at IS NOT NULL")
  end
end
