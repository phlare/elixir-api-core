defmodule ElixirApiCoreWeb.Plugs.RequireSystemAdmin do
  @moduledoc """
  Halts the request unless the current user is a system admin.

  Requires the `Auth` plug to have run first (needs `current_user` in assigns).

  ## Usage in router

      pipeline :system_admin do
        plug ElixirApiCoreWeb.Plugs.Auth
        plug ElixirApiCoreWeb.Plugs.RequireSystemAdmin
      end
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %{is_system_admin: true} ->
        conn

      _ ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.put_view(json: ElixirApiCoreWeb.ErrorJSON)
        |> Phoenix.Controller.render("error.json",
          code: "forbidden",
          message: "System admin access required"
        )
        |> halt()
    end
  end
end
