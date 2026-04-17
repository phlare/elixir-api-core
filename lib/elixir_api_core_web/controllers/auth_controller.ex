defmodule ElixirApiCoreWeb.AuthController do
  use ElixirApiCoreWeb, :controller

  alias ElixirApiCore.Auth
  alias ElixirApiCore.Auth.Cookie
  alias ElixirApiCore.Auth.RateLimits

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
    with {:ok, _remaining} <- RateLimits.check_login(client_ip(conn)),
         {:ok, result} <- Auth.login(params) do
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

    with {:ok, _remaining} <- RateLimits.check_refresh(client_ip(conn)),
         {:ok, result} <- Auth.refresh(params) do
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

  @oauth_state_cookie "_oauth_state"
  @oauth_state_max_age 600

  def google_start(conn, _params) do
    with {:ok, {url, state}} <- Auth.google_authorize_url() do
      conn
      |> put_resp_cookie(@oauth_state_cookie, state,
        http_only: true,
        secure: Cookie.secure?(),
        same_site: "Lax",
        max_age: @oauth_state_max_age,
        sign: true
      )
      |> json(%{data: %{authorize_url: url}})
    end
  end

  def google_callback(conn, params) do
    conn = fetch_cookies(conn, signed: [@oauth_state_cookie])

    with :ok <- verify_oauth_state(conn, params),
         {:ok, result} <- Auth.google_callback(params) do
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
      |> delete_resp_cookie(@oauth_state_cookie, sign: true)
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

  def verify_email(conn, %{"token" => token}) when is_binary(token) do
    case Auth.verify_email(token) do
      {:ok, _user} ->
        redirect(conn, external: app_url("/?email_verified=1"))

      {:error, :email_already_verified} ->
        redirect(conn, external: app_url("/?email_verified=1"))

      {:error, _reason} ->
        redirect(conn, external: app_url("/?error=invalid_token"))
    end
  end

  def verify_email(conn, _params) do
    redirect(conn, external: app_url("/?error=invalid_token"))
  end

  def send_verification(conn, _params) do
    user = conn.assigns.current_user

    with {:ok, _remaining} <-
           RateLimits.check_send_verification(user.id <> ":" <> client_ip(conn)),
         {:ok, _} <- Auth.send_verification_email(user) do
      json(conn, %{data: %{status: "ok"}})
    end
  end

  def request_password_reset(conn, %{"email" => email}) when is_binary(email) do
    bucket_key = email |> String.trim() |> String.downcase() |> Kernel.<>(":#{client_ip(conn)}")

    with {:ok, _remaining} <- RateLimits.check_password_reset(bucket_key),
         {:ok, _} <- Auth.request_password_reset(email) do
      json(conn, %{data: %{status: "ok"}})
    end
  end

  def request_password_reset(conn, _params) do
    json(conn, %{data: %{status: "ok"}})
  end

  def reset_password(conn, %{"token" => token, "password" => password})
      when is_binary(token) and is_binary(password) do
    with {:ok, _user} <- Auth.reset_password(token, password) do
      json(conn, %{data: %{status: "ok"}})
    end
  end

  def reset_password(_conn, _params) do
    {:error, :invalid_email_token}
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

  defp client_ip(conn) do
    conn.remote_ip |> :inet.ntoa() |> to_string()
  end

  defp verify_oauth_state(conn, params) do
    cookie_state = conn.cookies[@oauth_state_cookie]
    param_state = Map.get(params, "state") || Map.get(params, :state)

    cond do
      is_nil(cookie_state) or is_nil(param_state) -> {:error, :invalid_oauth_state}
      Plug.Crypto.secure_compare(cookie_state, param_state) -> :ok
      true -> {:error, :invalid_oauth_state}
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

  defp app_url(path) do
    base =
      Application.get_env(:elixir_api_core, ElixirApiCore.Email, [])
      |> Keyword.fetch!(:app_url)

    base <> path
  end
end
