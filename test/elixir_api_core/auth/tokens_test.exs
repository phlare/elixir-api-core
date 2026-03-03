defmodule ElixirApiCore.Auth.TokensTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Auth.RefreshToken
  alias ElixirApiCore.Auth.Tokens

  describe "access tokens" do
    test "issues and verifies access tokens" do
      user = user_fixture()
      account = account_fixture()
      now = ~U[2026-03-03 10:00:00Z]

      assert {:ok, token, claims} =
               Tokens.issue_access_token(user.id, account.id, :owner, now: now)

      assert is_binary(token)
      assert claims["user_id"] == user.id
      assert claims["account_id"] == account.id
      assert claims["role"] == "owner"

      assert {:ok, verified} =
               Tokens.verify_access_token(token, now: DateTime.add(now, 60, :second))

      assert verified.user_id == user.id
      assert verified.account_id == account.id
      assert verified.role == "owner"
    end

    test "returns expired_token for expired access token" do
      user = user_fixture()
      account = account_fixture()
      now = ~U[2026-03-03 10:00:00Z]

      assert {:ok, token, _claims} =
               Tokens.issue_access_token(user.id, account.id, :member, now: now, ttl_seconds: 1)

      assert {:error, :expired_token} =
               Tokens.verify_access_token(token, now: DateTime.add(now, 2, :second))
    end

    test "returns invalid_token for malformed token" do
      assert {:error, :invalid_token} = Tokens.verify_access_token("not-a-token")
    end

    test "returns invalid_role when issuing with unsupported role" do
      user = user_fixture()
      account = account_fixture()

      assert {:error, :invalid_role} =
               Tokens.issue_access_token(user.id, account.id, "super_admin")
    end

    test "returns invalid_token when role claim type is invalid" do
      now = ~U[2026-03-03 10:00:00Z]
      issuer = Application.fetch_env!(:elixir_api_core, Tokens)[:jwt_issuer]
      secret = Application.fetch_env!(:elixir_api_core, Tokens)[:jwt_secret]

      claims = %{
        "sub" => Ecto.UUID.generate(),
        "user_id" => Ecto.UUID.generate(),
        "account_id" => Ecto.UUID.generate(),
        "role" => 123,
        "iat" => DateTime.to_unix(now),
        "exp" => DateTime.to_unix(DateTime.add(now, 60, :second)),
        "iss" => issuer,
        "jti" => Ecto.UUID.generate()
      }

      jwk = JOSE.JWK.from_oct(secret)
      header = %{"alg" => "HS256", "typ" => "JWT"}
      {_, token} = JOSE.JWT.sign(jwk, header, claims) |> JOSE.JWS.compact()

      assert {:error, :invalid_token} =
               Tokens.verify_access_token(token, now: DateTime.add(now, 1, :second))
    end
  end

  describe "refresh tokens" do
    test "issues refresh token storing only hashed token" do
      user = user_fixture()
      now = ~U[2026-03-03 10:00:00Z]

      assert {:ok, issued} = Tokens.issue_refresh_token(user.id, now: now)
      assert is_binary(issued.token)
      assert String.length(issued.token) > 20
      assert issued.refresh_token.token_hash != issued.token
      assert issued.refresh_token.user_id == user.id
      assert :active == Tokens.refresh_token_status(issued.token, now: now)
    end

    test "rotates refresh tokens and revokes the old token" do
      user = user_fixture()
      now = ~U[2026-03-03 10:00:00Z]

      assert {:ok, issued} = Tokens.issue_refresh_token(user.id, now: now)

      assert {:ok, rotation} =
               Tokens.rotate_refresh_token(issued.token, now: DateTime.add(now, 60, :second))

      assert rotation.user_id == user.id
      assert is_binary(rotation.refresh_token)
      assert rotation.refresh_token != issued.token
      assert :revoked == Tokens.refresh_token_status(issued.token, now: now)
      assert :active == Tokens.refresh_token_status(rotation.refresh_token, now: now)
    end

    test "detects refresh token reuse and revokes active tokens for user" do
      user = user_fixture()
      now = ~U[2026-03-03 10:00:00Z]

      assert {:ok, issued} = Tokens.issue_refresh_token(user.id, now: now)

      assert {:ok, rotation} =
               Tokens.rotate_refresh_token(issued.token, now: DateTime.add(now, 10, :second))

      assert :active == Tokens.refresh_token_status(rotation.refresh_token, now: now)

      assert {:error, :refresh_token_reuse_detected} =
               Tokens.rotate_refresh_token(issued.token, now: DateTime.add(now, 20, :second))

      assert :revoked == Tokens.refresh_token_status(rotation.refresh_token, now: now)
    end

    test "returns expired_refresh_token for expired refresh token on rotate" do
      user = user_fixture()
      now = ~U[2026-03-03 10:00:00Z]

      assert {:ok, issued} = Tokens.issue_refresh_token(user.id, now: now, ttl_seconds: 1)

      assert {:error, :expired_refresh_token} =
               Tokens.rotate_refresh_token(issued.token, now: DateTime.add(now, 5, :second))
    end

    test "revoke_refresh_token marks token as revoked" do
      user = user_fixture()
      now = ~U[2026-03-03 10:00:00Z]

      assert {:ok, issued} = Tokens.issue_refresh_token(user.id, now: now)

      assert {:ok, %RefreshToken{} = refreshed} =
               Tokens.revoke_refresh_token(issued.token, now: now)

      assert not is_nil(refreshed.revoked_at)
      assert :revoked == Tokens.refresh_token_status(issued.token, now: now)
    end

    test "returns invalid_refresh_token for unknown token revoke" do
      assert {:error, :invalid_refresh_token} = Tokens.revoke_refresh_token("unknown-token")
    end

    test "hash function is deterministic" do
      token = "sample-token"
      assert Tokens.hash_refresh_token(token) == Tokens.hash_refresh_token(token)
    end

    test "hash function returns sha256 hex length" do
      hash = Tokens.hash_refresh_token("sample-token")
      assert String.length(hash) == 64
    end
  end
end
