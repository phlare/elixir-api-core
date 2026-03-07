defmodule ElixirApiCoreWeb.UserController do
  use ElixirApiCoreWeb, :controller

  def me(conn, _params) do
    user = conn.assigns.current_user
    membership = conn.assigns.current_membership

    json(conn, %{
      data: %{
        user: %{
          id: user.id,
          email: user.email,
          display_name: user.display_name
        },
        account_id: conn.assigns.current_account_id,
        role: conn.assigns.current_role,
        membership_id: membership.id
      }
    })
  end
end
