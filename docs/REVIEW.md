# Code Review: elixir-api-core v0.1 (Phases 0–2)

> **Resolution status:** All items in this review have been addressed as of v0.1. Critical items (C1–C3) were resolved in Phase 2.1 and Phase 6. High items (H1–H3) were resolved in Phase 2.1. Medium items (M1–M10) were resolved across Phases 3–7. Low items (L1–L4) were resolved in Phase 2.1 and Phase 3. This document is retained as a historical artifact.

This document captures a review of the plan and all committed code through Phase 2. It was read before Phase 3 work began.

---

## Plan vs. Implementation Consistency

| Item | Plan | Tracker | Code | Status |
|------|------|---------|------|--------|
| Phoenix scaffold | ✓ | ✓ | ✓ | Done |
| Migrations + schemas | ✓ | ✓ | ✓ | Done |
| JWT service | ✓ | ✓ | ✓ | Done |
| Refresh token rotation | ✓ | ✓ | ✓ | Done |
| Reuse detection | ✓ | ✓ | ✓ | Done |
| Rate limiting | ✓ | ✓ | ✓ | Done |
| CI skeleton | ✓ | ✓ | ✓ | Done |
| Auth endpoints (Phase 3) | ✓ | ○ | ✗ | Not started — expected |
| Request context plugs | ✓ | ○ | ✗ | Not started — expected |
| **Password hashing library** | implicit | implicit | ✗ | **Missing from deps** |
| Oban | ✓ (Phase 6) | ○ | ✗ | Not yet — expected |
| OpenAPI | ✓ (Phase 6) | ○ | ✗ | Not yet — expected |
| `/api/v1` routing | ✓ | ✓ | ✗ | Router uses `/api` not `/api/v1` |
| Fail-fast config validation | ✓ (Phase 6) | ○ | ✗ | Not yet — expected |

---

## CRITICAL — Blocking Issues

### C1. Password hashing library is missing from `mix.exs`

The domain model and Phase 3 plan require password verification in the login flow. Neither `bcrypt_elixir` nor `argon2_elixir` appears in deps. The identity fixture in `test/support/fixtures/accounts_fixtures.ex` uses the plaintext string `"hashed-password"` as a placeholder. Any real login implementation will fail without this library. Add before Phase 3.

**Recommendation:** Add `{:bcrypt_elixir, "~> 3.0"}` (or argon2) to `mix.exs` and document the choice in `docs/DECISIONS.md`.

### C2. Oban not in `mix.exs` or supervision tree

Phase 6 (still in v0.1 scope) requires Oban for async job queues (refresh token cleanup, example worker). This is expected to be missing at this stage but is a required dep before v0.1 ships. Note it in pre-Phase 6 setup.

### C3. No startup config validation

The default JWT secret `"dev_jwt_secret_change_me"` and pepper `"dev_refresh_pepper_change_me"` are set in `config/config.exs` with no guard to prevent production use. `runtime.exs` requires `DATABASE_URL` and `SECRET_KEY_BASE` but silently passes through the dev token secrets. PLAN.md explicitly calls for fail-fast startup config validation in Phase 6 — this should be treated as a blocking acceptance gate before declaring v0.1 done.

---

## HIGH — Security Issues

### H1. Refresh token pepper uses string concatenation instead of HMAC

**File:** `lib/elixir_api_core/auth/tokens.ex`

```elixir
# Current
:crypto.hash(:sha256, raw_token <> pepper)

# Better
:crypto.mac(:hmac, :sha256, pepper, raw_token)
```

Appending the pepper to plaintext before hashing is semantically weaker than HMAC — an attacker with knowledge of the pepper can still brute-force tokens more efficiently. HMAC is available in OTP 23+ and is a low-effort fix.

### H2. Email validation regex is too permissive

**File:** `lib/elixir_api_core/accounts/user.ex`

The current pattern `~r/^[^\s]+@[^\s]+$/` accepts `a@b`, `@test.com`, `test@.`, etc. At minimum use `~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/` and enforce a max length of 320 chars (RFC 5321). A dedicated library would be better for a template that downstream services will rely on.

### H3. `issue_access_token/1` builds JWT claims without type validation

**File:** `lib/elixir_api_core/auth/tokens.ex`

No guard ensures `user_id`, `account_id`, and `role` are the expected types (strings/atoms) before JOSE signs them. A non-string `role` atom could produce silently malformed JWT claims. Add explicit coercion or a function-head guard.

---

## MEDIUM — Code Quality, Inefficiency, and Test Gaps

### M1. `owner_count_for_update/1` fetches all owner IDs instead of using COUNT

**File:** `lib/elixir_api_core/accounts.ex`

```elixir
# Current — fetches all owner membership IDs into memory
|> Repo.all()
|> length()

# Better — single integer result
from(m in Membership, where: ..., select: count(m.id))
|> Repo.one()
```

### M2. Refresh token expiry not validated in the changeset

**File:** `lib/elixir_api_core/auth/refresh_token.ex`

No check that `expires_at` is in the future. The rotation path catches already-expired tokens, but the schema should reject inserting an already-expired token outright. Add a `validate_change` asserting `expires_at > DateTime.utc_now()`.

### M3. Token hash length validation is too loose

**File:** `lib/elixir_api_core/auth/refresh_token.ex`

Validates length 32–512, but SHA-256 hex output is always exactly 64 characters. Tighten to an exact-length check.

### M4. Router prefix is `/api` but spec and plan say `/api/v1`

**File:** `lib/elixir_api_core_web/router.ex`

`docs/API_SPEC.md` and `PLAN.md` both specify the `/api/v1` namespace. Fix this before any endpoints are added — changing it after will be a breaking URL change.

### M5. Test gaps in `tokens_test.exs`

Missing coverage:
- Revoking an already-revoked token (idempotency — what's the expected result?)
- Token with valid signature but wrong issuer claim
- Role roundtrip: atom `:owner` issued → string `"owner"` verified (or consistent type throughout)
- Refresh token issued with a past `expires_at` (should changeset reject this?)

### M6. Test gaps in `schemas_test.exs`

Missing coverage:
- Email regex edge cases (should `a@b` be accepted or rejected?)
- Email at 320-char boundary
- Account name at 1-char and 160-char boundaries
- Identity `password_hash` is nil for a password provider (should be rejected)

### M7. Test gaps in `rate_limits_test.exs`

Missing coverage:
- The Nth request — exactly at the limit (should it pass or fail?)
- `RateLimiter.reset/1` if the function exists (verify and test)

### M8. Test gaps in `membership_invariants_test.exs`

Missing coverage:
- Deleting a non-owner membership (should always succeed)
- Promoting `:member` to `:owner` when another owner already exists (should succeed)
- Attempting to set an invalid role (rejected at changeset level, not invariant level)

### M9. `ConnCase` lacks auth helpers

**File:** `test/support/conn_case.ex`

No helpers for setting a Bearer token or simulating an authenticated request. These will be needed for every controller test in Phase 4. Add `conn_with_token/2` (or similar) before Phase 4 begins.

### M10. Identity fixture uses plaintext password hash

**File:** `test/support/fixtures/accounts_fixtures.ex`

`password_hash: "hashed-password"` is a placeholder. Once a real hashing library is added, this fixture must produce a properly hashed value, or the test will never exercise the real verify path.

---

## LOW — Cleanup and Documentation

### L1. Verify `demoting_last_owner?/2` guard ordering

**File:** `lib/elixir_api_core/accounts.ex`

The function short-circuits before querying when `membership.role != :owner`. Confirm the guard is evaluated before `owner_count_for_update` is called in all code paths — the query should never fire for non-owner memberships.

### L2. Confirm `rotate_refresh_token` handles the reuse-detection tuple correctly

The inner `Repo.rollback({:refresh_token_reuse_detected, user_id})` causes `Repo.transaction` to return `{:error, {:refresh_token_reuse_detected, user_id}}`. Verify the caller in `rotate_refresh_token/1` pattern-matches on `{:error, ...}` for this case, not `{:ok, ...}`. A misread error tag would cause silent bugs when Phase 3 callers are added.

### L3. `DECISIONS.md` is missing key decisions

Not documented: password hashing algorithm, refresh token transport (body vs HttpOnly cookie — noted in PLAN.md locked decisions but absent from DECISIONS.md), JWT algorithm rationale, and OpenAPI tooling choice.

### L4. No `(user_id, provider)` compound index on `identities`

The login flow will look up identities by `(user_id, provider)`. Currently only indexed by `(provider, provider_uid)`. Add before Phase 3 queries land.

---

## Summary Priority Order for Phase 3 Prep

1. **Add password hashing library** (C1) — blocks Phase 3 login flow entirely
2. **Fix router prefix to `/api/v1`** (M4) — structural change, cheap now, breaking later
3. **Switch pepper to HMAC** (H1) — low effort, meaningful security improvement
4. **Tighten email validation** (H2) — template quality signal
5. **Add `conn_with_token/2` to `ConnCase`** (M9) — needed before writing any Phase 4 tests
6. **Fix `owner_count_for_update` to use COUNT** (M1) — simple query optimization
7. **Add expiry validation to refresh token changeset** (M2) — schema correctness
8. **Address test gaps M5–M8** — work through as Phase 3/4 tests are written
