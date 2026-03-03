# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Assistant Role

This project is implemented by Codex. Claude Code assists with **code review, plan validation, and identifying issues** — not with writing or committing implementation code. See `REVIEW.md` for the current review findings.

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

# Pre-commit checks (compile warnings, unused deps, formatting, tests)
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

**`ElixirApiCore.*`** — business logic, split into two contexts:
- `Accounts` — User, Account, Membership CRUD and invariant enforcement
- `Auth` — Token services, rate limiting, Identity/RefreshToken schemas

**`ElixirApiCoreWeb.*`** — Phoenix HTTP layer (endpoint, router, controllers, plugs). Currently minimal — auth endpoints are Phase 3 work.

### Domain Model

Five DB tables (all UUID PKs, UTC timestamps):
- **accounts** — the tenancy boundary; all data scoped to an account
- **users** — cross-account identity (email unique globally)
- **memberships** — joins users ↔ accounts with role (`owner | admin | member`); unique per (user, account)
- **identities** — auth credentials per user: `password` (stores `password_hash`) or `google` (stores `provider_uid`)
- **refresh_tokens** — opaque tokens stored as hashed values with expiry/revocation

### Token Strategy

- **Access tokens**: short-lived JWT (15 min), claims: `user_id`, `account_id`, `role`, `exp`, `iat`, `iss`, `jti`. Signed with HS256 via `jose`.
- **Refresh tokens**: opaque random bytes, hashed (SHA-256 + pepper) before DB storage, 30-day TTL, rotated on every use.
- **Reuse detection**: replaying a revoked refresh token triggers revocation of *all* active tokens for that user.

### Rate Limiting

`ElixirApiCore.Auth.RateLimiter` is a GenServer backed by ETS. Two buckets configured in `config.exs`:
- `login`: 5 attempts per 60s window
- `refresh`: 10 attempts per 60s window

### Key Invariants

- **Owner invariant**: every account must always have at least one `owner` membership. Enforced transactionally in `ElixirApiCore.Accounts` using `SELECT FOR UPDATE` row locking before any role change or membership deletion.
- **Account scoping**: all queries must be account-scoped; cross-account leakage is prevented at the context layer.

### Configuration

App config lives under module keys, e.g. `Application.get_env(:elixir_api_core, ElixirApiCore.Auth.Tokens)`. Sensitive values (`jwt_secret`, `refresh_token_pepper`, `DATABASE_URL`, `SECRET_KEY_BASE`) are loaded from env vars in `config/runtime.exs`. Dev/test use plaintext defaults in `config/config.exs`.

### Error Format

All API errors use a stable envelope:
```json
{ "error": { "code": "...", "message": "...", "details": {} } }
```

## Testing

- Uses `DataCase` (SQL Sandbox, async-safe) for all DB tests
- Test factories live in `test/support/fixtures/accounts_fixtures.ex`
- Auth tests cover JWT lifecycle, refresh token rotation, reuse detection, and rate limit windows
- Membership invariant tests use concurrent transactions to verify owner protection

## Current Status (v0.1)

Phases 0–2 complete: data model, schemas/changesets, JWT + refresh token services, rate limiting, owner invariant, CI.

Phases 3–7 pending: HTTP auth endpoints (`/auth/register`, `/login`, `/refresh`, `/logout`, `/me`), request context plugs, Google OAuth, OpenAPI spec, Oban workers.

See `docs/CODEX_TASK.md` for the living task tracker and `docs/ARCHITECTURE.md` for detailed design decisions.
