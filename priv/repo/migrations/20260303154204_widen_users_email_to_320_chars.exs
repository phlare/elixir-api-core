defmodule ElixirApiCore.Repo.Migrations.WidenUsersEmailTo320Chars do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :email, :string, size: 320, null: false
    end
  end
end
