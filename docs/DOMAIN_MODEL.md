# Domain Model — Elixir API Core

This document defines the foundational identity, tenancy, and authorization model
for all services built on this template.

---

# Core Concepts

- Accounts are the primary data ownership boundary.
- Users authenticate and may belong to multiple accounts.
- Memberships define a user’s role within an account.
- Identities represent authentication providers.
- JWT access tokens authorize API access.
- Refresh tokens allow session continuation.

---

# Entities

## Account

Represents a tenant boundary.

Fields:
- id (uuid)
- name (string)
- inserted_at
- updated_at

Constraints:
- Accounts own domain data.
- Deleting an account cascades or soft-deletes owned data.

---

## User

Represents a human principal.

Fields:
- id (uuid)
- email (string, unique)
- display_name (string, optional)
- inserted_at
- updated_at

Constraints:
- Email must be globally unique.
- A user may belong to multiple accounts.

---

## Membership

Join table connecting users to accounts.

Fields:
- id (uuid)
- user_id (fk)
- account_id (fk)
- role (enum: owner | admin | member)
- inserted_at
- updated_at

Constraints:
- (user_id, account_id) unique
- At least one owner must exist per account
- Role changes must enforce at least one owner

---

## Identity

Represents authentication provider linkage.

Fields:
- id (uuid)
- user_id (fk)
- provider (enum: password | google | future)
- provider_uid (string, nullable for password)
- password_hash (nullable, only for provider=password)
- inserted_at
- updated_at

Constraints:
- (provider, provider_uid) unique when provider_uid not null
- A user may have multiple identities
- Password identity must store password_hash
- OAuth identities must store provider_uid

---

## RefreshToken

Stores refresh tokens for session continuation and revocation.

Fields:
- id (uuid)
- user_id (fk)
- token_hash (string)
- expires_at (utc_datetime)
- revoked_at (utc_datetime, nullable)
- inserted_at
- updated_at

Constraints:
- token_hash unique
- Revoked tokens cannot be reused
- Expired tokens invalid

Security:
- Store hashed refresh tokens, never raw
- Rotate refresh tokens upon use

---

# JWT Strategy

## Access Token
- Signed JWT
- Short-lived (e.g., 15 minutes)
- Contains:
  - user_id
  - account_id (active account)
  - role
  - exp
  - jti (optional)

## Refresh Token
- Opaque random string
- Stored hashed in DB
- Long-lived (e.g., 30 days)
- Rotated on each refresh

---

# Authorization Model (RBAC v1)

Roles:
- owner
- admin
- member

Permissions (initial policy idea):

owner:
- full account control
- manage members
- delete account

admin:
- manage most resources
- cannot delete account
- cannot remove owner

member:
- access account resources
- cannot manage members

Authorization enforcement:
- Role checked via membership record
- Policies defined per controller/context

Future:
- Permission table or policy module expansion
- Role-per-resource support

---

# Multi-Account Behavior

Users may belong to multiple accounts.

Access token must include an active account_id.

Switching accounts:
- Requires new access token issued for selected account.

---

# Invariants

- Every account must have at least one owner.
- A user must have at least one membership to log in.
- Refresh tokens must be hashed.
- Access tokens must be short-lived.
- No cross-account data leakage.

---

# Template Boundary

This template defines:
- Identity
- Tenancy
- Authentication
- Authorization foundation

It does NOT define:
- Domain-specific schemas
- Feature-specific permissions