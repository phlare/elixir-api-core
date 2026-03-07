# elixir-api-core Implementation Plan

## Summary
Build `elixir-api-core` as a Phoenix API template focused on identity, tenancy, and auth foundations only.
Track delivery in `CHANGELOG.md` as a versioned changelog.

## Current Status
- v0.1 complete (122 tests, 10 endpoints, all phases delivered).
- Next planned: v0.2 (cookie transport for refresh tokens).

## Locked Decisions
- Runtime: Elixir `1.19.5` + OTP `28` (pin in `.tool-versions` and CI).
- Docker compose scope: Postgres only.
- Refresh transport: JSON body (v0.1); HttpOnly cookie planned for v0.2.
- OAuth: Google supported out of the box via config-driven adapter.
- OpenAPI: include template-level contract in `v0.1`.
- Rollout: core `v0.1` shipped, broader platform additions in `v0.2+`.

## v0.1 Delivered
- Phoenix API scaffolded and runnable.
- Postgres wired with local `docker-compose.yml`.
- Migrations/schemas: accounts, users, memberships, identities, refresh_tokens, audit_events.
- Endpoints (all under `/api/v1` except health):
  - `GET /healthz`, `GET /readyz`
  - `POST /auth/register`, `POST /auth/login`
  - `POST /auth/refresh`, `POST /auth/logout`
  - `POST /auth/switch_account`
  - `GET /me`
  - `GET /auth/google/start`, `GET /auth/google/callback`
- JWT access tokens + opaque refresh tokens (HMAC-hashed, rotated, revocable).
- Refresh rotation with reuse detection.
- Request context plugs for `current_user/current_account/current_role/current_membership`.
- Standard JSON success/error envelopes and error codes.
- Owner invariant enforcement with row-level locking.
- ETS-backed auth rate limiting.
- Google OAuth with configurable provider (mock in tests).
- Oban background jobs (example + cleanup workers).
- Fail-fast startup config validation (blocks unsafe prod secrets).
- OpenAPI 3.1 spec for core platform endpoints.
- CI skeleton: `mix format --check-formatted` + `mix test`.
- API lifecycle conventions with `/api/v1` namespace policy.

## v0.2+ Roadmap
See `CHANGELOG.md` for the detailed planned backlog (v0.2 through v0.8).

## Test and Validation Strategy
- Run focused tests after each endpoint/context slice.
- Run full `mix test` at each milestone.
- 122 tests covering:
  - register/login/refresh/logout/switch-account happy + failure paths
  - refresh rotation and replay detection
  - `/me` auth/context behavior
  - cross-account denial and membership role invariants
  - Google OAuth callback linking/create flows (mocked adapter)
  - error envelope/code consistency
  - health/readiness behavior
  - auth endpoint rate limiting
  - Oban worker execution
  - config validation

## Definition of Done (v0.1) — Met
- `mix test` passes (122 tests, 0 failures).
- `mix phx.server` runs.
- Core auth flows work locally against Postgres.
- OpenAPI contract present.
- `CHANGELOG.md` shows v0.1 checklist complete and v0.2+ backlog seeded.
