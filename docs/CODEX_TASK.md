# Codex Task: Bootstrap elixir-api-core

This file is a living, versioned deliverables tracker for the template.

## Source of Truth Docs
- `docs/PRODUCT_BRIEF.md`
- `docs/DOMAIN_MODEL.md`
- `docs/ARCHITECTURE.md`
- `docs/API_SPEC.md`
- `docs/DECISIONS.md`
- `docs/PLATFORM_TEMPLATES.md`

## Tracking Policy
- Keep this file long-term and add sections per template version (`v0.1`, `v0.2`, ...).
- Mark checklist items as complete only after tests pass for the covered scope.
- Keep template-only boundaries: no product-domain logic, no Slack/MCP adapters.

## v0.1 Deliverables (In Progress)
- [x] Phoenix API project scaffolded and runnable.
- [x] Postgres wired + `docker-compose` for local dev (Postgres service only).
- [x] Runtime pinned to Elixir `1.19.5` + OTP `28` (`.tool-versions` and CI).
- [x] Schemas + migrations:
  - [x] `accounts`
  - [x] `users`
  - [x] `memberships` (`owner/admin/member`)
  - [x] `identities` (`password` + `google`)
  - [x] `refresh_tokens` (hashed, revocable, expirable)
- [ ] Auth/account endpoints:
  - [ ] `POST /auth/register`
  - [ ] `POST /auth/login`
  - [ ] `POST /auth/refresh` (rotation)
  - [ ] `POST /auth/logout` (revoke)
  - [ ] `POST /auth/switch_account`
  - [ ] `GET /me`
  - [ ] `GET /healthz`
  - [ ] `GET /readyz`
  - [ ] `GET /auth/google/start`
  - [ ] `GET /auth/google/callback`
- [x] JWT access tokens + opaque refresh tokens implemented.
- [x] Refresh token storage is hashed-only (no raw token persistence).
- [ ] Refresh transport supports JSON body + HttpOnly cookie.
- [x] Refresh rotation + replay/reuse detection behavior implemented.
- [ ] Request plugs set `current_user/current_account/current_role/current_membership`.
- [ ] Error format standardized (`validation_error`, `auth_error`, `not_found`, etc.).
- [ ] OpenAPI baseline contract added for core platform endpoints.
- [ ] Oban installed/configured + example worker + cleanup worker skeleton.
- [x] Auth-focused rate limiting baseline in place.
- [ ] Minimal audit event foundation for core auth/membership events.
- [ ] Config contract with fail-fast startup validation.
- [ ] API lifecycle conventions documented (`/api/v1`, deprecation/error-code policy).
- [x] CI skeleton in place (`mix format --check-formatted`, `mix test`).

## v0.1 Action Breakdown (Execution Order)

### Phase 0: Scaffold and Baseline
- [x] Generate Phoenix API app in-place (preserve `docs/`).
- [x] Add `.tool-versions` pinning Elixir `1.19.5` and OTP `28`.
- [x] Configure `config/dev.exs`, `config/test.exs`, and repo wiring for Postgres.
- [x] Add `docker-compose.yml` with local Postgres service only.
- [x] Add CI workflow running formatting and tests.

Acceptance gate:
- [x] `mix deps.get`
- [x] `mix ecto.create`
- [x] `mix test` (initial generated tests)

### Phase 1: Data Model and Migrations
- [x] Create migrations for `accounts`, `users`, `memberships`, `identities`, `refresh_tokens`.
- [x] Add DB constraints/indexes:
  - [x] unique user email
  - [x] unique membership `(user_id, account_id)`
  - [x] membership role check (`owner|admin|member`)
  - [x] identity uniqueness on `(provider, provider_uid)` when uid present
  - [x] unique refresh token hash
- [x] Create Ecto schemas + changesets for all core entities.
- [x] Add transactional invariant checks for owner-preservation logic.

Acceptance gate:
- [x] `mix ecto.migrate`
- [x] schema/changeset tests for constraints and validations
- [x] `mix test`

### Phase 2: Token and Auth Core Services
- [x] Implement JWT service (sign/verify claims: user/account/role/exp).
- [x] Implement opaque refresh token generator + hash/verify helper.
- [x] Implement refresh token persistence, revocation, expiry checks, and rotation.
- [x] Implement reuse detection path (revoked refresh token replay response and user token revocation policy).
- [x] Add auth-focused rate limit primitives for login/refresh.

Acceptance gate:
- [x] unit tests for JWT creation/verification
- [x] unit tests for refresh rotation/replay detection
- [x] rate-limit behavior tests
- [x] `mix test`

### Pre-Phase 3: Code Review

Review `REVIEW.md` before starting Phase 3. Priority items to address first:
- Add password hashing library to `mix.exs` (blocks login flow)
- Fix router scope from `/api` to `/api/v1`
- Switch refresh token pepper to HMAC (`crypto.mac/4`)
- Add `conn_with_token/2` helper to `ConnCase` (needed for Phase 4 tests)

### Phase 3: Accounts/Auth Contexts
- [ ] Implement Accounts context operations for memberships and account switching checks.
- [ ] Implement Auth context flows:
  - [ ] register (user + account + owner membership + password identity)
  - [ ] login (password verification, account resolution)
  - [ ] refresh (rotation and issuance)
  - [ ] logout (token revoke)
  - [ ] switch account (membership verification + new access token)
- [ ] Add minimal audit event foundation and auth/membership event writes.

Acceptance gate:
- [ ] context tests for each flow (success + failure)
- [ ] owner-invariant tests
- [ ] `mix test`

### Phase 4: Web Layer and Request Context
- [ ] Add auth pipeline and plugs:
  - [ ] bearer token parsing/verification
  - [ ] current user/account/membership loading
  - [ ] role assignment and mismatch handling
- [ ] Implement JSON response helpers and fallback error serialization.
- [ ] Add versioned routing (`/api/v1`) and required endpoints:
  - [ ] `GET /healthz`
  - [ ] `GET /readyz`
  - [ ] `POST /auth/register`
  - [ ] `POST /auth/login`
  - [ ] `POST /auth/refresh` (body + cookie support)
  - [ ] `POST /auth/logout`
  - [ ] `POST /auth/switch_account`
  - [ ] `GET /me`

Acceptance gate:
- [ ] controller tests for all required endpoints
- [ ] consistent error envelope assertions
- [ ] `mix test`

### Phase 5: Google OAuth Integration
- [ ] Define OAuth provider behavior and default Google adapter.
- [ ] Implement `GET /auth/google/start` URL construction.
- [ ] Implement `GET /auth/google/callback` exchange/profile/linking flow.
- [ ] Implement linking rules:
  - [ ] existing google identity -> login
  - [ ] existing user by email -> link identity
  - [ ] new user -> create user/account/membership/identity

Acceptance gate:
- [ ] adapter-mocked controller/context tests
- [ ] missing/invalid config tests
- [ ] `mix test`

### Phase 6: Oban, OpenAPI, and Config Contract
- [ ] Configure Oban repo/queues.
- [ ] Add template example worker.
- [ ] Add cleanup worker skeleton for expired refresh tokens.
- [ ] Add OpenAPI spec for core platform endpoints and schemas.
- [ ] Add fail-fast startup config validation for DB/JWT/refresh/OAuth/Oban.
- [ ] Document API lifecycle conventions (versioning/deprecation/error codes).

Acceptance gate:
- [ ] worker tests (basic enqueue/perform expectations)
- [ ] OpenAPI validation/lint check passing
- [ ] boot failure tests for missing required config
- [ ] `mix test`

### Phase 7: Final Hardening and Release Readiness
- [ ] Update README with local setup, runtime pin, Postgres compose usage, and run/test commands.
- [ ] Verify `mix format --check-formatted`.
- [ ] Run full test suite and fix regressions.
- [ ] Mark completed `v0.1` checklist items in this file.
- [ ] Seed/adjust `v0.2` backlog based on what was deferred.

Acceptance gate:
- [ ] `mix format --check-formatted`
- [ ] `mix test`
- [ ] `mix phx.server` boots successfully

## v0.1 Definition of Done
- [ ] `mix test` passes.
- [ ] `mix phx.server` runs.
- [ ] Register/login/refresh/logout/switch-account flows work locally with Postgres.
- [ ] OpenAPI contract checks pass in CI.

## v0.2 Backlog (Planned)
- [ ] Observability expansion (metrics/traces packaging and defaults).
- [ ] Auth hardening expansion (session inventory/revocation UX).
- [ ] Tenant-safety enforcement extras (stronger guardrails/tooling).
- [ ] Audit trail querying and retention policy.
- [ ] Idempotency framework rollout examples for downstream services.
- [ ] Rate-limit expansion beyond auth endpoints.
- [ ] API lifecycle CI enforcement for compatibility/deprecation rules.
- [ ] Advanced readiness/dependency health matrix.
