# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Phoenix API template for multi-tenant identity, authentication, and authorization. This is a reusable foundation — it contains no product logic, only auth/tenancy/identity primitives. Elixir 1.19.5 + OTP 28.3.3 (pinned in `.tool-versions`).

## Commands

```bash
# First-time setup (installs deps + creates/migrates DB)
mix setup

# Development server
mix phx.server

# Run all tests (auto-creates and migrates test DB)
mix test

# Run a single test file
mix test test/elixir_api_core/auth/tokens_test.exs

# Run a single test by line number
mix test test/elixir_api_core/auth/tokens_test.exs:42

# Pre-commit checks (compile warnings, unused deps, formatting, tests, dialyzer)
mix precommit

# Database management
mix ecto.reset        # drop + recreate + migrate + seed
mix ecto.migrate      # run pending migrations

# Code formatting
mix format
mix format --check-formatted   # used in CI
```

Local Postgres runs via Docker: `docker-compose up -d`

## Architecture

### Namespaces

**`ElixirApiCore.*`** — business logic, split into three contexts:
- `Accounts` — User, Account, Membership CRUD and invariant enforcement
- `Auth` — Token services, rate limiting, Identity/RefreshToken schemas, Google OAuth
- `Audit` — Event logging for auth and membership actions

**`ElixirApiCoreWeb.*`** — Phoenix HTTP layer (endpoint, router, controllers, plugs, fallback controller). Serves 10 endpoints under `/api/v1` plus health checks at root.

### Domain Model

Five core DB tables (all UUID PKs, UTC timestamps):
- **accounts** — the tenancy boundary; all data scoped to an account
- **users** — cross-account identity (email unique globally)
- **memberships** — joins users ↔ accounts with role (`owner | admin | member`); unique per (user, account)
- **identities** — auth credentials per user: `password` (stores `password_hash`) or `google` (stores `provider_uid`)
- **refresh_tokens** — opaque tokens stored as hashed values with expiry/revocation

Plus **audit_events** (append-only event log) and **oban_jobs** (background job queue).

### Token Strategy

- **Access tokens**: short-lived JWT (15 min), claims: `user_id`, `account_id`, `role`, `exp`, `iat`, `iss`, `jti`. Signed with HS256 via `jose`.
- **Refresh tokens**: opaque random bytes, hashed (SHA-256 HMAC + pepper) before DB storage, 30-day TTL, rotated on every use. Delivered via JSON body and optionally via HttpOnly cookie (`ElixirApiCore.Auth.Cookie`).
- **Reuse detection**: replaying a revoked refresh token triggers revocation of *all* active tokens for that user.

### Rate Limiting

`ElixirApiCore.Auth.RateLimiter` is a GenServer backed by ETS. Two buckets configured in `config.exs`:
- `login`: 5 attempts per 60s window
- `refresh`: 10 attempts per 60s window

### Google OAuth

Configurable `OAuthProvider` behaviour with a default Google adapter. Test suite uses a mock provider via `Application.get_env(:elixir_api_core, :oauth_provider)`. Three linking rules: existing identity → login, existing email → link identity, new → create user/account/membership/identity.

### Background Jobs

Oban with `default` and `maintenance` queues. `CleanupExpiredTokensWorker` runs daily at 03:00 UTC via `Oban.Plugins.Cron` to remove expired/revoked refresh tokens. Includes an example worker for job conventions.

### Tenant Safety

- **Owner invariant**: every account must always have at least one `owner` membership. Enforced transactionally in `ElixirApiCore.Accounts` using `SELECT FOR UPDATE` row locking before any role change or membership deletion.
- **Account scoping**: use `ElixirApiCore.Repo.Scoped` helpers (`where_account/2`, `scoped_get/3`, `scoped_all/2`) for all account-scoped queries. Guards reject nil `account_id` at runtime.
- **RequireAccountScope plug**: wired into the `:authenticated` pipeline as defense-in-depth; halts with 403 if `current_account_id` is missing.

### Configuration

App config lives under module keys, e.g. `Application.get_env(:elixir_api_core, ElixirApiCore.Auth.Tokens)`. Sensitive values (`jwt_secret`, `refresh_token_pepper`, `DATABASE_URL`, `SECRET_KEY_BASE`) are loaded from env vars in `config/runtime.exs`. Dev/test use plaintext defaults in `config/config.exs`. Fail-fast validation at boot blocks unsafe default secrets in production (`ElixirApiCore.Config.validate!/0`).

### Error Format

All API errors use a stable envelope:
```json
{ "error": { "code": "...", "message": "...", "details": {} } }
```

## Testing

- 145 tests, 0 failures
- Uses `DataCase` (SQL Sandbox, async-safe) for DB tests and `ConnCase` for controller tests
- Test factories live in `test/support/fixtures/accounts_fixtures.ex`
- `conn_with_token/2` helper in `ConnCase` for authenticated request tests
- `setup_tenant_pair/0` helper in `DataCase` for cross-tenant isolation tests
- Auth tests cover JWT lifecycle, refresh token rotation, reuse detection, and rate limit windows
- Membership invariant tests use concurrent transactions to verify owner protection
- Google OAuth tests use a mock provider configured in `config/test.exs`
- Oban tests use `Oban.Testing` with `testing: :inline` mode

## Current Status

v0.2 complete. See `CHANGELOG.md` for the versioned task tracker and `docs/ARCHITECTURE.md` for detailed design.
