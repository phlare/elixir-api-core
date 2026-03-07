defmodule ElixirApiCore.Audit do
  @moduledoc """
  Minimal audit event foundation. Write-only log of auth and membership events.
  Querying and retention are deferred to v0.2.
  """

  alias ElixirApiCore.Audit.Event
  alias ElixirApiCore.Repo

  @doc """
  Logs an audit event. Returns `{:ok, event}` or `{:error, changeset}`.
  """
  def log(attrs) when is_map(attrs) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end
end
