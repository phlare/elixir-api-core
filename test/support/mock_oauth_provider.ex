defmodule ElixirApiCore.Auth.MockOAuthProvider do
  @behaviour ElixirApiCore.Auth.OAuthProvider

  @impl true
  def authorize_url(state) do
    {:ok, "https://mock.oauth.example.com/authorize?state=#{state}"}
  end

  @impl true
  def exchange_code("valid_code") do
    {:ok,
     %{
       email: Process.get(:mock_oauth_email, "google@example.com"),
       provider_uid: Process.get(:mock_oauth_uid, "google-uid-123"),
       name: Process.get(:mock_oauth_name, "Google User")
     }}
  end

  def exchange_code("invalid_code") do
    {:error, {:token_exchange_failed, 401}}
  end

  def exchange_code(_code) do
    {:error, {:token_exchange_failed, 400}}
  end
end
