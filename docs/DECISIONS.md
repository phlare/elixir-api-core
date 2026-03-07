# Decision Log — Elixir API Core

This file records foundational decisions to keep future work coherent.

---

## 001 — Template-first approach
We are building reusable service templates to accelerate future projects.
Business logic lives in downstream repos.

## 002 — Multi-tenant from day one
Accounts are first-class. Users can belong to multiple accounts via memberships.

## 003 — RBAC v1 (simple roles)
We start with owner/admin/member roles on memberships.
Future expansion may include per-resource permissions.

## 004 — Auth uses JWT access + refresh tokens
Access tokens are short-lived JWTs.
Refresh tokens are opaque, stored hashed in Postgres, revocable, and rotated.

## 005 — OAuth identities are linkable
Users may authenticate with email/password and also link OAuth identities (Google first).

## 006 — Adapters remain thin
External integration services (Slack, MCP, etc.) will call the core API and not duplicate business logic.

## 007 — Password hashing uses bcrypt
Password identities use `bcrypt_elixir` for password hashing and verification.
Test fixtures should generate real bcrypt hashes so login/verify paths use realistic data.

## 008 — Refresh transport supports body and HttpOnly cookie
Refresh token endpoints support:
- request body `refresh_token` for API/service clients
- HttpOnly cookie transport for browser clients

## 009 — JWT signing uses HS256 in template baseline
Access tokens are signed with HS256 using a configured secret.
Production deployments must provide non-default secrets; default development values are not permitted in prod validation.

## 010 — OpenAPI contract is template-level and endpoint-focused
OpenAPI is maintained for core platform endpoints in this template.
Downstream product/domain endpoints are added in downstream repos and can extend the base contract.

## 011 — API lifecycle conventions
- All API endpoints are versioned under `/api/v1`.
- New versions (e.g. `/api/v2`) are introduced only for breaking changes.
- Non-breaking additions (new fields, new endpoints) are added in-place.
- Deprecated endpoints or fields should include a `deprecated: true` annotation in the OpenAPI spec and a `X-Deprecated` response header before removal.
- Error codes are stable strings (e.g. `invalid_credentials`, `validation_error`) and must not be renamed once shipped.
- New error codes may be added but existing codes must remain backward-compatible.

## 012 — Oban for background job processing
Oban is used for background job processing with PostgreSQL-backed queues.
Two queues are configured: `default` (general work) and `maintenance` (cleanup tasks).
The cleanup worker deletes expired and revoked refresh tokens.

## 013 — Fail-fast startup config validation
The application validates required configuration at boot via `ElixirApiCore.Config.validate!/0`.
In production, unsafe default values for `jwt_secret` and `refresh_token_pepper` cause a startup crash.
This prevents accidental deployment with development secrets.
