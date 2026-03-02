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
- [ ] Phoenix API project scaffolded and runnable.
- [ ] Postgres wired + `docker-compose` for local dev (Postgres service only).
- [ ] Runtime pinned to Elixir `1.19.5` + OTP `28` (`.tool-versions` and CI).
- [ ] Schemas + migrations:
  - [ ] `accounts`
  - [ ] `users`
  - [ ] `memberships` (`owner/admin/member`)
  - [ ] `identities` (`password` + `google`)
  - [ ] `refresh_tokens` (hashed, revocable, expirable)
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
- [ ] JWT access tokens + opaque refresh tokens implemented.
- [ ] Refresh token storage is hashed-only (no raw token persistence).
- [ ] Refresh transport supports JSON body + HttpOnly cookie.
- [ ] Refresh rotation + replay/reuse detection behavior implemented.
- [ ] Request plugs set `current_user/current_account/current_role/current_membership`.
- [ ] Error format standardized (`validation_error`, `auth_error`, `not_found`, etc.).
- [ ] OpenAPI baseline contract added for core platform endpoints.
- [ ] Oban installed/configured + example worker + cleanup worker skeleton.
- [ ] Auth-focused rate limiting baseline in place.
- [ ] Minimal audit event foundation for core auth/membership events.
- [ ] Config contract with fail-fast startup validation.
- [ ] API lifecycle conventions documented (`/api/v1`, deprecation/error-code policy).
- [ ] CI skeleton in place (`mix format --check-formatted`, `mix test`).

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
