# API Spec (Baseline) — Elixir API Core

This document defines the baseline endpoints provided by the template.

All endpoints are JSON unless otherwise noted.

---

## Response Conventions

### Success
- `200/201` with JSON body
- Stable envelope recommended:
  - `{ "data": ... }`

### Errors
Stable error shape:
- `{ "error": { "code": "...", "message": "...", "details": ... } }`

Validation errors:
- `{ "error": { "code": "validation_error", "message": "Invalid request", "details": { "field": ["msg"] } } }`

---

## Health

### GET /healthz
Returns 200 if the API process is healthy.

Response:
- `{ "data": { "status": "ok" } }`

---

## Auth — Email/Password

### POST /auth/register
Creates a user, a new account, and an owner membership.

Request:
- email (string)
- password (string)
- display_name (string, optional)
- account_name (string, optional)

Response:
- user summary
- account summary
- tokens:
  - access_token
  - refresh_token

### POST /auth/login
Request:
- email (string)
- password (string)

Response:
- tokens:
  - access_token
  - refresh_token
- accounts list (optional convenience)
- active account (optional)

### POST /auth/refresh
Rotates refresh token and issues new access token.

Request:
- refresh_token (string)

Response:
- access_token
- refresh_token

### POST /auth/logout
Revokes the presented refresh token (and optionally all refresh tokens for user).

Request:
- refresh_token (string) OR use cookie

Response:
- `{ "data": { "status": "ok" } }`

---

## Auth — Google OAuth

### GET /auth/google/start
Redirects to Google OAuth authorization URL.

### GET /auth/google/callback
Handles OAuth callback, links identity, issues tokens.
Response:
- access_token
- refresh_token

---

## Account Switching

### POST /auth/switch_account
Issues a new access token for a different account the user belongs to.

Request:
- account_id (uuid)

Response:
- access_token
- account summary

---

## Accounts

### GET /accounts
Returns accounts current user belongs to.

### GET /accounts/:id
Returns account details if user is a member.

---

## Memberships (RBAC v1)

### GET /accounts/:account_id/members
List memberships (role + user summary)

Authorization:
- owner/admin only

### POST /accounts/:account_id/members
Invite or add a user (initially: add existing user by email)

Authorization:
- owner/admin only

### PATCH /accounts/:account_id/members/:membership_id
Change role.

Authorization:
- owner only (or owner/admin with restrictions)

---

## Users

### GET /me
Returns current user + current account + role.