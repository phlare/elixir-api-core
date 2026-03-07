defmodule ElixirApiCore.Config do
  @moduledoc """
  Fail-fast startup config validation.

  Called during application boot to ensure all required configuration
  is present and that unsafe defaults are not used in production.
  """

  require Logger

  @unsafe_jwt_secrets ["dev_jwt_secret_change_me", ""]
  @unsafe_refresh_peppers ["dev_refresh_pepper_change_me", ""]

  def validate! do
    errors =
      []
      |> validate_tokens_config()
      |> validate_production_secrets()

    case errors do
      [] ->
        :ok

      errors ->
        message =
          ["Configuration validation failed:"] ++
            Enum.map(errors, &("  - " <> &1))

        raise message |> Enum.join("\n")
    end
  end

  defp validate_tokens_config(errors) do
    config = Application.get_env(:elixir_api_core, ElixirApiCore.Auth.Tokens, [])

    errors
    |> require_key(config, :jwt_secret, "Auth.Tokens :jwt_secret is required")
    |> require_key(config, :jwt_issuer, "Auth.Tokens :jwt_issuer is required")
    |> require_key(config, :refresh_token_pepper, "Auth.Tokens :refresh_token_pepper is required")
  end

  defp validate_production_secrets(errors) do
    if production?() do
      config = Application.get_env(:elixir_api_core, ElixirApiCore.Auth.Tokens, [])
      jwt_secret = Keyword.get(config, :jwt_secret)
      pepper = Keyword.get(config, :refresh_token_pepper)

      errors
      |> then(fn errs ->
        if jwt_secret in @unsafe_jwt_secrets do
          ["Auth.Tokens :jwt_secret must not use the default dev value in production" | errs]
        else
          errs
        end
      end)
      |> then(fn errs ->
        if pepper in @unsafe_refresh_peppers do
          [":refresh_token_pepper must not use the default dev value in production" | errs]
        else
          errs
        end
      end)
    else
      errors
    end
  end

  defp require_key(errors, config, key, message) do
    case Keyword.get(config, key) do
      nil -> [message | errors]
      "" -> [message | errors]
      _ -> errors
    end
  end

  defp production? do
    Application.get_env(:elixir_api_core, :env) == :prod
  end
end
