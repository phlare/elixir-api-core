defmodule ElixirApiCore.Repo.Migrations.AddIdentitiesUserProviderIndex do
  use Ecto.Migration

  def change do
    create index(:identities, [:user_id, :provider], name: :identities_user_provider_index)
  end
end
