defmodule ElixirApiCoreWeb.AuthController do
  use ElixirApiCoreWeb, :controller

  alias ElixirApiCore.Auth

  action_fallback ElixirApiCoreWeb.FallbackController

  def register(conn, params) do
    with {:ok, result} <- Auth.register(params) do
      conn
      |> put_status(:created)
      |> json(%{
        data: %{
          user: user_json(result.user),
          account: account_json(result.account),
          access_token: result.access_token,
          refresh_token: result.refresh_token
        }
      })
    end
  end

  def login(conn, params) do
    with {:ok, result} <- Auth.login(params) do
      json(conn, %{
        data: %{
          user: user_json(result.user),
          access_token: result.access_token,
          refresh_token: result.refresh_token,
          active_account_id: result.active_account_id,
          accounts:
            Enum.map(result.memberships, fn m ->
              %{account_id: m.account_id, role: m.role}
            end)
        }
      })
    end
  end

  def refresh(conn, params) do
    with {:ok, result} <- Auth.refresh(params) do
      json(conn, %{
        data: %{
          access_token: result.access_token,
          refresh_token: result.refresh_token
        }
      })
    end
  end

  def logout(conn, params) do
    with {:ok, _} <- Auth.logout(params) do
      json(conn, %{data: %{status: "ok"}})
    end
  end

  def switch_account(conn, %{"account_id" => account_id}) do
    user_id = conn.assigns.current_user.id

    with {:ok, result} <- Auth.switch_account(user_id, account_id) do
      json(conn, %{
        data: %{
          access_token: result.access_token,
          account_id: result.account_id,
          role: result.role
        }
      })
    end
  end

  defp user_json(user) do
    %{id: user.id, email: user.email, display_name: user.display_name}
  end

  defp account_json(account) do
    %{id: account.id, name: account.name}
  end
end
