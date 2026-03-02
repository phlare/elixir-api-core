# Elixir API Core — Product Brief

## Purpose

Elixir API Core is a reusable Phoenix-based backend template for building API-first, multi-tenant applications.

It provides:
- Multi-user account model
- JWT authentication (access + refresh tokens)
- OAuth provider linking (Google initially)
- Background job infrastructure
- Consistent API conventions
- Health + observability baseline

It intentionally contains **no business domain logic**.

It is a platform foundation.

---

## Goals

- Accelerate creation of new backend services
- Enforce consistent architectural patterns
- Provide production-ready authentication and tenancy from day one
- Separate core infrastructure from business logic
- Serve as a long-term reusable internal template

---

## Non-Goals

- UI scaffolding
- Domain-specific schemas
- Feature-specific workflows
- Billing logic
- Role-heavy enterprise RBAC (initially)

---

## Architectural Principles

1. API-first design
2. Multi-tenant by default
3. Account-scoped data isolation
4. JWT access tokens + refresh tokens
5. OAuth providers are linkable identities
6. Background jobs are first-class
7. Clear error contracts
8. Business logic lives outside this template

---

## Intended Usage

Future projects will:
1. Use this repository as a template
2. Add domain schemas
3. Add domain-specific endpoints
4. Keep core infra untouched

---

## Success Criteria

- Can register/login via email/password
- Can login via Google OAuth
- JWT tokens issued and refreshable
- Requests scoped to account
- Background job system operational
- Health endpoint operational
- Clean JSON error formatting