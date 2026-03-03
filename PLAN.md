# elixir-api-core Implementation Plan

## Summary
Build `elixir-api-core` as a Phoenix API template focused on identity, tenancy, and auth foundations only.  
Track delivery in `docs/CODEX_TASK.md` as a living versioned checklist.

## Current Status
- Completed: Phase 0 scaffold and baseline setup.
- Completed: Phase 1 core data model (migrations, schemas, owner invariants, validation tests).
- Completed checks: `mix deps.get`, `mix ecto.create`, `mix test`.
- In progress next: Phase 2 (JWT + refresh token core services).

## Locked Decisions
- Runtime: Elixir `1.19.5` + OTP `28` (pin in `.tool-versions` and CI).
- Docker compose scope: Postgres only.
- Refresh transport: JSON body + HttpOnly cookie.
- OAuth: Google supported out of the box via config-driven adapter.
- OpenAPI: include template-level contract in `v0.1`.
- Rollout: ship core `v0.1` now, keep broader platform additions in `v0.2`.

## v0.1 Scope (Implement Now)
- Phoenix API scaffolded and runnable.
- Postgres wired with local `docker-compose.yml`.
- Migrations/schemas: accounts, users, memberships, identities, refresh_tokens.
- Endpoints:
  - `GET /healthz`
  - `GET /readyz`
  - `POST /auth/register`
  - `POST /auth/login`
  - `POST /auth/refresh`
  - `POST /auth/logout`
  - `POST /auth/switch_account`
  - `GET /me`
  - `GET /auth/google/start`
  - `GET /auth/google/callback`
- JWT access tokens + opaque refresh tokens (hashed, rotated, revocable).
- Request context plugs for `current_user/current_account/current_role/current_membership`.
- Standard JSON success/error envelopes and error codes.
- Oban installed/configured with:
  - example worker
  - expired refresh-token cleanup worker skeleton
- CI skeleton:
  - `mix format --check-formatted`
  - `mix test`
- OpenAPI contract for core platform endpoints only.
- Fail-fast startup config validation (DB/JWT/refresh/OAuth/Oban essentials).
- API lifecycle conventions with `/api/v1` namespace policy.

## v0.2 Scope (Planned Next)
- Observability expansion (metrics/traces packaging).
- Auth hardening expansion (session inventory/revocation UX).
- Tenant-safety enforcement extras.
- Audit trail querying + retention.
- Idempotency framework adoption examples.
- Rate-limit expansion beyond auth endpoints.
- API lifecycle CI enforcement.
- Advanced readiness/dependency health matrix.

## Test and Validation Strategy
- Run focused tests after each endpoint/context slice.
- Run full `mix test` at each milestone.
- Required coverage:
  - register/login/refresh/logout/switch-account happy + failure paths
  - refresh rotation and replay detection
  - body/cookie refresh transport paths
  - `/me` auth/context behavior
  - cross-account denial and membership role invariants
  - Google OAuth callback linking/create flows (mocked adapter)
  - error envelope/code consistency
  - health/readiness behavior
  - auth endpoint rate limiting
  - OpenAPI validation checks in CI

## Definition of Done (v0.1)
- `mix test` passes.
- `mix phx.server` runs.
- Core auth flows work locally against Postgres.
- OpenAPI contract validates in CI.
- `docs/CODEX_TASK.md` shows `v0.1` checklist complete and `v0.2` backlog seeded.
