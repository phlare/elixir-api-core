defmodule ElixirApiCore.ConfigTest do
  use ExUnit.Case, async: false

  alias ElixirApiCore.Config

  describe "validate!/0" do
    test "passes with valid dev/test config" do
      assert :ok = Config.validate!()
    end

    test "raises when jwt_secret is missing" do
      original = Application.get_env(:elixir_api_core, ElixirApiCore.Auth.Tokens)

      Application.put_env(
        :elixir_api_core,
        ElixirApiCore.Auth.Tokens,
        Keyword.delete(original, :jwt_secret)
      )

      assert_raise RuntimeError, ~r/jwt_secret is required/, fn ->
        Config.validate!()
      end
    after
      restore_config()
    end

    test "raises when refresh_token_pepper is missing" do
      original = Application.get_env(:elixir_api_core, ElixirApiCore.Auth.Tokens)

      Application.put_env(
        :elixir_api_core,
        ElixirApiCore.Auth.Tokens,
        Keyword.delete(original, :refresh_token_pepper)
      )

      assert_raise RuntimeError, ~r/refresh_token_pepper is required/, fn ->
        Config.validate!()
      end
    after
      restore_config()
    end

    test "blocks unsafe jwt_secret in production" do
      Application.put_env(:elixir_api_core, :env, :prod)

      assert_raise RuntimeError, ~r/must not use the default dev value/, fn ->
        Config.validate!()
      end
    after
      Application.put_env(:elixir_api_core, :env, :test)
    end
  end

  defp restore_config do
    Application.put_env(:elixir_api_core, ElixirApiCore.Auth.Tokens,
      jwt_algorithm: "HS256",
      jwt_issuer: "elixir_api_core",
      jwt_secret: "dev_jwt_secret_change_me",
      access_token_ttl_seconds: 900,
      refresh_token_ttl_seconds: 2_592_000,
      refresh_token_pepper: "dev_refresh_pepper_change_me"
    )
  end
end
