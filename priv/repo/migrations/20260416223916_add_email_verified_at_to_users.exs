defmodule ElixirApiCore.Repo.Migrations.AddEmailVerifiedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :email_verified_at, :utc_datetime
    end
  end
end
