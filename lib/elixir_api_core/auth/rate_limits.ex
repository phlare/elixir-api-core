defmodule ElixirApiCore.Auth.RateLimits do
  alias ElixirApiCore.Auth.RateLimiter

  def check_login(identifier, opts \\ []) do
    do_check(:login, identifier, :login_limit, :login_window_seconds, opts)
  end

  def check_refresh(identifier, opts \\ []) do
    do_check(:refresh, identifier, :refresh_limit, :refresh_window_seconds, opts)
  end

  def check_send_verification(identifier, opts \\ []) do
    do_check(
      :send_verification,
      identifier,
      :send_verification_limit,
      :send_verification_window_seconds,
      opts
    )
  end

  def check_password_reset(identifier, opts \\ []) do
    do_check(
      :password_reset,
      identifier,
      :password_reset_limit,
      :password_reset_window_seconds,
      opts
    )
  end

  defp do_check(bucket, identifier, limit_key, window_key, opts) do
    limit = config(limit_key)
    window_seconds = config(window_key)
    limiter_opts = Keyword.take(opts, [:now_ms])

    case RateLimiter.allow(bucket, identifier, limit, window_seconds, limiter_opts) do
      {:allow, remaining} -> {:ok, remaining}
      {:deny, retry_after} -> {:error, {:rate_limited, retry_after}}
    end
  end

  defp config(key) do
    Application.get_env(:elixir_api_core, __MODULE__, [])
    |> Keyword.fetch!(key)
  end
end
