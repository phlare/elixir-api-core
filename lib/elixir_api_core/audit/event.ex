defmodule ElixirApiCore.Audit.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_events" do
    field :action, :string
    field :actor_id, :binary_id
    field :account_id, :binary_id
    field :resource_type, :string
    field :resource_id, :binary_id
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:action, :actor_id, :account_id, :resource_type, :resource_id, :metadata])
    |> validate_required([:action])
  end
end
