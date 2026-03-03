defmodule ElixirApiCore.Auth.RateLimitsTest do
  use ExUnit.Case, async: false

  alias ElixirApiCore.Auth.RateLimiter
  alias ElixirApiCore.Auth.RateLimits

  setup do
    RateLimiter.reset()
    :ok
  end

  test "check_login allows requests up to configured limit then rate limits" do
    identifier = "ip:10.0.0.1"

    assert {:ok, 4} = RateLimits.check_login(identifier, now_ms: 0)
    assert {:ok, 3} = RateLimits.check_login(identifier, now_ms: 1)
    assert {:ok, 2} = RateLimits.check_login(identifier, now_ms: 2)
    assert {:ok, 1} = RateLimits.check_login(identifier, now_ms: 3)
    assert {:ok, 0} = RateLimits.check_login(identifier, now_ms: 4)

    assert {:error, {:rate_limited, retry_after_seconds}} =
             RateLimits.check_login(identifier, now_ms: 5)

    assert retry_after_seconds > 0
  end

  test "check_login window resets after configured interval" do
    identifier = "ip:10.0.0.2"

    for now_ms <- 0..4 do
      assert {:ok, _remaining} = RateLimits.check_login(identifier, now_ms: now_ms)
    end

    assert {:error, {:rate_limited, _retry_after}} = RateLimits.check_login(identifier, now_ms: 5)
    assert {:ok, 4} = RateLimits.check_login(identifier, now_ms: 61_000)
  end

  test "reset/0 clears all buckets so exhausted identifiers are allowed again" do
    identifier = "ip:10.0.0.99"

    for now_ms <- 0..4 do
      RateLimits.check_login(identifier, now_ms: now_ms)
    end

    assert {:error, {:rate_limited, _}} = RateLimits.check_login(identifier, now_ms: 5)

    assert :ok = RateLimiter.reset()

    assert {:ok, 4} = RateLimits.check_login(identifier, now_ms: 5)
  end

  test "check_refresh uses independent bucket from login" do
    identifier = "user:123"

    for now_ms <- 0..4 do
      assert {:ok, _remaining} = RateLimits.check_login(identifier, now_ms: now_ms)
    end

    assert {:error, {:rate_limited, _retry_after}} = RateLimits.check_login(identifier, now_ms: 5)
    assert {:ok, 9} = RateLimits.check_refresh(identifier, now_ms: 5)
  end
end
