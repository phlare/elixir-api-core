defmodule ElixirApiCoreWeb.AuthController do
  use ElixirApiCoreWeb, :controller

  alias ElixirApiCore.Auth
  alias ElixirApiCore.Auth.Cookie

  action_fallback ElixirApiCoreWeb.FallbackController

  def register(conn, params) do
    with {:ok, result} <- Auth.register(params) do
      conn
      |> put_status(:created)
      |> put_refresh_cookie(result.refresh_token)
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
      conn
      |> put_refresh_cookie(result.refresh_token)
      |> json(%{
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
    params = maybe_read_cookie_token(params, conn)

    with {:ok, result} <- Auth.refresh(params) do
      conn
      |> put_refresh_cookie(result.refresh_token)
      |> json(%{
        data: %{
          access_token: result.access_token,
          refresh_token: result.refresh_token
        }
      })
    end
  end

  def logout(conn, params) do
    params = maybe_read_cookie_token(params, conn)

    with {:ok, _} <- Auth.logout(params) do
      conn
      |> delete_refresh_cookie()
      |> json(%{data: %{status: "ok"}})
    end
  end

  def google_start(conn, _params) do
    with {:ok, url} <- Auth.google_authorize_url() do
      json(conn, %{data: %{authorize_url: url}})
    end
  end

  def google_callback(conn, params) do
    with {:ok, result} <- Auth.google_callback(params) do
      status = if Map.has_key?(result, :account), do: :created, else: :ok

      data =
        %{
          user: user_json(result.user),
          access_token: result.access_token,
          refresh_token: result.refresh_token
        }
        |> maybe_put(:account, result[:account], &account_json/1)
        |> maybe_put(:accounts, result[:memberships], fn memberships ->
          Enum.map(memberships, fn m -> %{account_id: m.account_id, role: m.role} end)
        end)

      conn
      |> put_status(status)
      |> put_refresh_cookie(result.refresh_token)
      |> json(%{data: data})
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

  # Cookie helpers

  defp put_refresh_cookie(conn, token) do
    if Cookie.enabled?() do
      put_resp_cookie(conn, Cookie.name(), token, Cookie.options())
    else
      conn
    end
  end

  defp delete_refresh_cookie(conn) do
    if Cookie.enabled?() do
      put_resp_cookie(conn, Cookie.name(), "", Cookie.delete_options())
    else
      conn
    end
  end

  defp maybe_read_cookie_token(params, conn) do
    if has_refresh_token?(params) do
      params
    else
      conn = Plug.Conn.fetch_cookies(conn)

      case conn.cookies[Cookie.name()] do
        nil -> params
        "" -> params
        token -> Map.put(params, "refresh_token", token)
      end
    end
  end

  defp has_refresh_token?(params) do
    token = Map.get(params, "refresh_token") || Map.get(params, :refresh_token)
    is_binary(token) and token != ""
  end

  # JSON helpers

  defp user_json(user) do
    %{id: user.id, email: user.email, display_name: user.display_name}
  end

  defp account_json(account) do
    %{id: account.id, name: account.name}
  end

  defp maybe_put(map, _key, nil, _transform), do: map
  defp maybe_put(map, key, value, transform), do: Map.put(map, key, transform.(value))
end
