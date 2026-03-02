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