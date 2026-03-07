defmodule ElixirApiCoreWeb.Plugs.Auth do
  @moduledoc """
  Verifies the bearer token and loads the request context:
  current_user, current_account, current_membership, current_role.
  """

  import Plug.Conn

  alias ElixirApiCore.Accounts.{Membership, User}
  alias ElixirApiCore.Auth.Tokens
  alias ElixirApiCore.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- extract_bearer_token(conn),
         {:ok, claims} <- Tokens.verify_access_token(token),
         {:ok, user} <- load_user(claims.user_id),
         {:ok, membership} <- load_membership(claims.user_id, claims.account_id) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_account_id, claims.account_id)
      |> assign(:current_role, to_string(membership.role))
      |> assign(:current_membership, membership)
    else
      _error ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.put_view(json: ElixirApiCoreWeb.ErrorJSON)
        |> Phoenix.Controller.render("error.json",
          code: "unauthorized",
          message: "Invalid or missing access token"
        )
        |> halt()
    end
  end

  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end

  defp load_user(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp load_membership(user_id, account_id) do
    case Repo.get_by(Membership, user_id: user_id, account_id: account_id) do
      nil -> {:error, :membership_not_found}
      membership -> {:ok, membership}
    end
  end
end
