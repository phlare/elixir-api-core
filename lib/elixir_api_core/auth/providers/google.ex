defmodule ElixirApiCore.Auth.Providers.Google do
  @behaviour ElixirApiCore.Auth.OAuthProvider

  @authorize_url "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"
  @userinfo_url "https://www.googleapis.com/oauth2/v2/userinfo"
  @scope "openid email profile"

  @impl true
  def authorize_url(state) do
    with {:ok, config} <- fetch_config() do
      params =
        URI.encode_query(%{
          client_id: config.client_id,
          redirect_uri: config.redirect_uri,
          response_type: "code",
          scope: @scope,
          state: state,
          access_type: "offline",
          prompt: "consent"
        })

      {:ok, "#{@authorize_url}?#{params}"}
    end
  end

  @impl true
  def exchange_code(code) do
    with {:ok, config} <- fetch_config(),
         {:ok, token_data} <- request_token(code, config),
         {:ok, user_info} <- request_user_info(token_data["access_token"]) do
      {:ok,
       %{
         email: user_info["email"],
         provider_uid: user_info["id"],
         name: user_info["name"]
       }}
    end
  end

  defp request_token(code, config) do
    body = %{
      code: code,
      client_id: config.client_id,
      client_secret: config.client_secret,
      redirect_uri: config.redirect_uri,
      grant_type: "authorization_code"
    }

    case Req.post(@token_url, form: body) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:token_exchange_failed, status}}

      {:error, reason} ->
        {:error, {:token_exchange_failed, reason}}
    end
  end

  defp request_user_info(access_token) do
    case Req.get(@userinfo_url, headers: [{"authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:userinfo_failed, status}}

      {:error, reason} ->
        {:error, {:userinfo_failed, reason}}
    end
  end

  defp fetch_config do
    config = Application.get_env(:elixir_api_core, __MODULE__, [])
    client_id = Keyword.get(config, :client_id)
    client_secret = Keyword.get(config, :client_secret)
    redirect_uri = Keyword.get(config, :redirect_uri)

    if client_id && client_secret && redirect_uri do
      {:ok, %{client_id: client_id, client_secret: client_secret, redirect_uri: redirect_uri}}
    else
      {:error, :google_oauth_not_configured}
    end
  end
end
