# elixir-api-core Implementation Plan

## Summary
Build `elixir-api-core` as a Phoenix API template focused on identity, tenancy, and auth foundations only.  
Track delivery in `docs/CODEX_TASK.md` as a living versioned checklist.

## Current Status
- Completed: Phase 0 scaffold and baseline setup.
- Completed: Phase 1 core data model (migrations, schemas, owner invariants, validation tests).
- Completed: Phase 2 token/auth core services (JWT, refresh token rotation/reuse detection, rate limiting primitives).
- Completed: Phase 2.1 review-driven hardening adjustments.
- Completed checks: `mix deps.get`, `mix ecto.create`, `mix test`.
- In progress next: Phase 3 (Accounts/Auth business flows built on top of token services).

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

## Phase 2.1 Review-Driven Adjustments (Before Phase 3)
- Add password hashing dependency and wire fixtures/helpers to use real password hashes.
- Switch refresh token hashing from `sha256(raw <> pepper)` to HMAC-SHA256.
- Tighten email validation and add boundary/edge-case tests.
- Add stricter access-token claim type validation and tests.
- Add `(user_id, provider)` index for `identities` before auth lookup paths are added.
- Update router namespace to `/api/v1` before endpoint implementation begins.
- Tighten refresh token schema validation:
  - `token_hash` must be exact SHA-256 hex length.
  - `expires_at` must be in the future.
- Add `ConnCase` auth helper (`conn_with_token/2`) before Phase 4 controller tests.
- Document security/auth decisions in `docs/DECISIONS.md`:
  - password hashing algorithm
  - refresh token transport choice
  - JWT algorithm rationale
  - OpenAPI tooling choice

## Review Items Integrated Into Future Phases
- Phase 3:
  - Phase 3 preamble / review-closure tasks:
    - optimize `owner_count_for_update/1` query path (or document/justify lock strategy with evidence)
    - add explicit `RateLimiter.reset/0` behavior test
    - expand membership invariant tests (non-owner delete, member->owner promote, invalid role update rejection)
    - add targeted test ensuring `demoting_last_owner?/2` avoids owner-count query for non-owner memberships
    - preamble gate: tests pass, full `mix test` green, and M1/M7/M8/L1 explicitly marked addressed in tracker
  - define idempotent revoked-token behavior expectations in auth context (`revoke` semantics)
  - confirm reuse-detection return contract with context-level tests
- Phase 4:
  - rely on `conn_with_token/2` for authenticated controller coverage
  - add wrong-issuer and malformed-token request coverage through plugs/controllers
- Phase 6:
  - add Oban dependency/supervision and cleanup worker implementation
  - enforce fail-fast startup validation for JWT/refresh secrets (production-safe guardrails)
- Phase 7:
  - close remaining schema/token/rate-limit edge-case tests from review not already completed in earlier phases

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
