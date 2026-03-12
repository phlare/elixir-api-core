# Changelog — elixir-api-core

Versioned deliverables tracker for the platform template.

## Source of Truth Docs
- `docs/PRODUCT_BRIEF.md`
- `docs/DOMAIN_MODEL.md`
- `docs/ARCHITECTURE.md`
- `docs/API_SPEC.md`
- `docs/DECISIONS.md`
---

## v0.0.1 — Scaffold and Baseline

- [x] Generate Phoenix API app in-place (preserve `docs/`).
- [x] Add `.tool-versions` pinning Elixir `1.19.5` and OTP `28`.
- [x] Configure `config/dev.exs`, `config/test.exs`, and repo wiring for Postgres.
- [x] Add `docker-compose.yml` with local Postgres service only.
- [x] Add CI workflow running formatting and tests.

## v0.0.2 — Data Model and Migrations

- [x] Create migrations for `accounts`, `users`, `memberships`, `identities`, `refresh_tokens`.
- [x] Add DB constraints/indexes:
  - [x] unique user email
  - [x] unique membership `(user_id, account_id)`
  - [x] membership role check (`owner|admin|member`)
  - [x] identity uniqueness on `(provider, provider_uid)` when uid present
  - [x] unique refresh token hash
- [x] Create Ecto schemas + changesets for all core entities.
- [x] Add transactional invariant checks for owner-preservation logic.

## v0.0.3 — Token and Auth Core Services

- [x] Implement JWT service (sign/verify claims: user/account/role/exp).
- [x] Implement opaque refresh token generator + hash/verify helper.
- [x] Implement refresh token persistence, revocation, expiry checks, and rotation.
- [x] Implement reuse detection path (revoked refresh token replay response and user token revocation policy).
- [x] Add auth-focused rate limit primitives for login/refresh.

### v0.0.3.1 — Review-Driven Hardening

- [x] Add password hashing dependency (`bcrypt_elixir`) and wire test fixtures to generate real password hashes.
- [x] Switch refresh-token hashing from concatenation to HMAC (`:crypto.mac/4`).
- [x] Tighten email validation and add boundary/edge-case tests.
- [x] Add explicit JWT claim type validation/coercion tests.
- [x] Add `identities(user_id, provider)` index for auth lookup path.
- [x] Update router namespace to `/api/v1`.
- [x] Tighten refresh-token changeset rules (exact hash length, reject expired `expires_at`).
- [x] Add `conn_with_token/2` helper in `ConnCase`.
- [x] Document security/auth/tooling decisions in `docs/DECISIONS.md`.

## v0.0.4 — Accounts/Auth Contexts

- [x] Document and justify `owner_count_for_update/1` lock strategy (PostgreSQL FOR UPDATE limitation).
- [x] Add `RateLimiter.reset/0` behavioral test.
- [x] Expand membership invariant tests (delete non-owner, promote to owner, invalid role rejection).
- [x] Add targeted test proving `demoting_last_owner?/2` short-circuits for non-owner memberships.
- [x] Implement Auth context flows:
  - [x] register (user + account + owner membership + password identity)
  - [x] login (password verification, account resolution)
  - [x] refresh (rotation and issuance)
  - [x] logout (token revoke)
  - [x] switch account (membership verification + new access token)
- [x] Add minimal audit event foundation and auth/membership event writes.
- [x] Define and test idempotent token-revoke semantics.
- [x] Confirm and test refresh reuse-detection error contract at context boundary.

## v0.0.5 — Web Layer and Request Context

- [x] Add auth pipeline and plugs (bearer token, current user/account/membership loading).
- [x] Implement JSON response helpers and fallback error serialization.
- [x] Add versioned routing (`/api/v1`) and required endpoints:
  - [x] `GET /healthz`, `GET /readyz`
  - [x] `POST /auth/register`, `POST /auth/login`
  - [x] `POST /auth/refresh`, `POST /auth/logout`
  - [x] `POST /auth/switch_account`
  - [x] `GET /me`
- [x] Controller tests with consistent error envelope assertions.

## v0.0.6 — Google OAuth Integration

- [x] Define `OAuthProvider` behaviour and default Google adapter.
- [x] Implement `GET /auth/google/start` URL construction.
- [x] Implement `GET /auth/google/callback` exchange/profile/linking flow.
- [x] Implement linking rules:
  - [x] existing google identity → login
  - [x] existing user by email → link identity
  - [x] new user → create user/account/membership/identity
- [x] Adapter-mocked controller and context tests.

## v0.0.7 — Oban, OpenAPI, and Config Contract

- [x] Configure Oban repo/queues (`default`, `maintenance`).
- [x] Add `ExampleWorker` and `CleanupExpiredTokensWorker`.
- [x] Add OpenAPI 3.1 spec for core platform endpoints (`priv/openapi/v1.yaml`).
- [x] Add fail-fast startup config validation (`ElixirApiCore.Config.validate!/0`).
- [x] Document API lifecycle conventions (versioning/deprecation/error codes).
- [x] Ensure production startup blocks unsafe default auth secrets.
- [x] Worker tests and boot failure tests.

## v0.1 — Release Readiness

- [x] Update README with local setup, runtime pin, Postgres compose usage, and run/test commands.
- [x] Verify `mix format --check-formatted`.
- [x] Run full test suite (122 tests, 0 failures).
- [x] Verify `mix phx.server` boots successfully.

### v0.1 Summary

- 122 tests passing
- 10 endpoints (`/healthz`, `/readyz`, register, login, refresh, logout, switch_account, Google start/callback, `/me`)
- 5 DB tables (accounts, users, memberships, identities, refresh_tokens) + audit_events + oban_jobs
- JWT access tokens (HS256, 15 min) + opaque refresh tokens (SHA-256 HMAC, 30 day, rotated)
- Refresh rotation with reuse detection
- Owner invariant enforcement with row-level locking
- ETS-backed auth rate limiting
- Google OAuth with configurable provider (mock in tests)
- Oban background jobs (example + cleanup workers)
- Fail-fast config validation (blocks unsafe prod secrets)
- OpenAPI 3.1 spec

### v0.1 Deferred

- Refresh transport: HttpOnly cookie support (JSON body works, cookie deferred to v0.2).

---

## v0.2 — Cookie Transport, Tooling, and Housekeeping

- [x] Add HttpOnly cookie support for refresh token transport.
- [x] Set `Set-Cookie` header on register/login/refresh/Google callback responses.
- [x] Read refresh token from cookie when not present in request body (refresh + logout).
- [x] Body param takes precedence over cookie when both are present.
- [x] Cookie cleared (max_age=0) on logout.
- [x] Cookie config: name, path, http_only, secure, same_site, max_age (configurable per environment).
- [x] Production enforces `secure: true`.
- [x] Cookie transport can be disabled via `enabled: false` config.
- [x] Add `dialyxir` and include dialyzer in `mix precommit`.
- [x] Fix dialyzer warnings (password spec, refresh token type reference).
- [x] Add `STYLE.md` coding conventions guide.
- [x] Add `CONTRIBUTING.md`.
- [x] Update docs (CLAUDE.md, README.md, DECISIONS.md) for v0.2 accuracy.
- [x] Trim roadmap to template-appropriate scope.
- [x] 130 tests passing, 0 dialyzer warnings.
- [x] Tenant-safety middleware: `RequireAccountScope` plug, `Repo.Scoped` query helpers, `setup_tenant_pair` test helper.
- [x] Oban `Cron` plugin scheduling `CleanupExpiredTokensWorker` daily at 03:00 UTC.
- [x] OpenAPI CI validation (Spectral lint) and breaking-change detection (oasdiff) in GitHub Actions.
- [x] 145 tests passing.

---

## v0.2.1 — Bug Fix and Housekeeping

- [x] Fix: logout crashes when no refresh token provided.
- [x] Add GitHub Sponsors funding configuration.
- [x] Add web-app-core cross-links to README.
- [x] Remove `docs/PLATFORM_TEMPLATES.md` (moved to `tiny-inbox-product/docs/`).
