# Architecture — Elixir API Core

Elixir API Core is a Phoenix API template that provides multi-tenant identity, auth,
and authorization foundations for future services.

It contains no business domain logic.

---

## Components

### Phoenix API
Responsibilities:
- HTTP API (JSON)
- Authentication (email/password + OAuth)
- Authorization (account-scoped RBAC)
- Token issuance (access + refresh)
- Request context (current_user, current_account, current_role)
- Validation + error formatting
- Health endpoints
- Background job enqueueing

### Postgres
Source of truth for:
- Users, Accounts, Memberships
- Identities (provider links)
- Refresh token store (hashed, revocable)

### Oban
Responsibilities:
- Email delivery jobs (later)
- OAuth / identity enrichment jobs (if needed)
- Scheduled maintenance jobs (cleanup expired refresh tokens)
- Template example job demonstrating job conventions

---

## Request Lifecycle (Authenticated)

1. Client sends `Authorization: Bearer <access_token>`
2. Auth plug verifies JWT signature and `exp`
3. Access token claims contain:
   - user_id
   - account_id (active tenant)
   - role (membership role)
4. Context plug loads:
   - current_user (by user_id)
   - current_account (by account_id)
   - current_membership (user_id + account_id)
5. Controllers/contexts scope all queries by current_account.id
6. Authorization checks role before protected actions

Notes:
- Role in the JWT is treated as a convenience hint; server-side membership is
  the authority if there is ever a mismatch.

---

## Login Flow (Email/Password)

1. User registers with email/password
2. System creates:
   - User
   - Account (optional: create personal account at signup)
   - Membership (role=owner)
   - Identity (provider=password, password_hash set)
3. User logs in:
   - Credentials verified
   - Access token issued (short-lived)
   - Refresh token issued (stored hashed)

---

## Login Flow (Google OAuth)

1. User completes OAuth login with Google
2. System receives provider_uid (Google subject) + email
3. System behavior:
   - If Identity(provider=google, uid=...) exists: log in as that user
   - Else if User(email=...) exists: link google identity to that user
   - Else: create user + account + owner membership + google identity
4. Issue access + refresh tokens

---

## Refresh Token Flow (Rotation)

1. Client calls `POST /auth/refresh` with refresh token (cookie or body)
2. Server hashes provided token and finds matching RefreshToken row
3. If token is expired or revoked: reject
4. Rotation:
   - revoke the old token row (revoked_at=now)
   - create a new RefreshToken row
   - issue new access token + new refresh token

Optional hardening (later):
- reuse detection: if a revoked token is presented again, revoke all active tokens
  for that user (or account) and force re-login

---

## Account Switching

A user may belong to multiple accounts. The active account is embedded in the access token.

Account switching requires issuing a new access token for the selected account:

- `POST /auth/switch_account { account_id }`
- Server verifies membership exists and returns a new access token
- Refresh token remains valid; it is user-scoped (not account-scoped)

---

## API Conventions

- JSON responses are consistent
- Errors have a stable shape (validation vs auth vs not found)
- All domain queries are account-scoped by default
- Pagination and filtering patterns are standardized in helpers

---

## Boundaries and Extensibility

This template is intended to be copied and extended.

A downstream service should:
- Add domain schemas and contexts
- Add resource controllers/routes
- Reuse the auth/tenancy/authorization infrastructure as-is

A downstream service should not:
- Modify identity/auth primitives unless upstreaming improvements back into the template