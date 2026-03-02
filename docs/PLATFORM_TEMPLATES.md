# Platform Templates Strategy

This repository is one of a set of reusable templates intended to reduce setup time for new services.

Templates are designed to be:
- generic
- functional
- opinionated
- easy to extend
- devoid of business domain logic

---

## Template Repositories

### elixir-api-core
Phoenix API starter providing:
- accounts/users/memberships
- identity model (password + OAuth providers)
- JWT access + refresh auth
- RBAC v1 scaffolding
- baseline API conventions
- Oban background job wiring
- health endpoint and dev ergonomics

### node-edge-core
TypeScript service starter intended for:
- Slack adapter services
- MCP servers
- webhook receivers
- small integration services

It provides:
- strict TS + lint/test
- env validation
- logging + request id
- health endpoint
- typed client to elixir-api-core services

---

## What Must Not Go Into Templates
- Product-specific schemas and workflows
- Feature-specific endpoints
- Business rules that do not generalize
- One-off hacks for a single downstream project

If something is genuinely general-purpose and will be used across multiple services,
it should be upstreamed into the template.

---

## Versioning
Templates should be versioned with tags (v0.1, v0.2, ...).

Downstream services should record which template version they started from.

---

## Upgrade Philosophy
Downstream repos are not required to “merge forward” from template changes.
Templates are a starting point, not a dependency.