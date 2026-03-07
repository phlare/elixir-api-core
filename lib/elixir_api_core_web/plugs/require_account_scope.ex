defmodule ElixirApiCoreWeb.Plugs.RequireAccountScope do
  @moduledoc """
  Safety-net plug that halts the request if `current_account_id` is not set.

  The `Auth` plug already guarantees this for authenticated routes, but this
  plug provides defense-in-depth: if a new pipeline is added without `Auth`,
  this plug will catch the missing scope before any data access occurs.

  ## Usage in router

      pipeline :authenticated do
        plug ElixirApiCoreWeb.Plugs.Auth
        plug ElixirApiCoreWeb.Plugs.RequireAccountScope
      end
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_account_id] do
      id when is_binary(id) ->
        conn

      _missing ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.put_view(json: ElixirApiCoreWeb.ErrorJSON)
        |> Phoenix.Controller.render("error.json",
          code: "missing_account_scope",
          message: "Request is missing account context"
        )
        |> halt()
    end
  end
end
