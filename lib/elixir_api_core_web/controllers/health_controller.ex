defmodule ElixirApiCoreWeb.HealthController do
  use ElixirApiCoreWeb, :controller

  alias ElixirApiCore.Repo

  def healthz(conn, _params) do
    json(conn, %{data: %{status: "ok"}})
  end

  def readyz(conn, _params) do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1") do
      {:ok, _} ->
        json(conn, %{data: %{status: "ok"}})

      {:error, _} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: %{code: "service_unavailable", message: "Database is not reachable"}})
    end
  end
end
