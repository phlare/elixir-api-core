# Platform Templates

Reusable project templates that provide infrastructure plumbing with zero business logic. Product services are created from these templates and then diverge freely.

## Template Repositories

| Template            | Purpose                   | Stack                                           |
| ------------------- | ------------------------- | ----------------------------------------------- |
| **elixir-api-core** | Backend API services      | Phoenix, Ecto, Postgres, JWT auth, multi-tenant |
| **node-edge-core**  | Edge/integration services | Fastify, Zod, Pino, TypeScript                  |
| **web-app-core**    | Frontend SPA applications | Vite, React, TypeScript, Tailwind               |

## What Belongs in a Template

- Project scaffolding and build configuration
- Environment validation and configuration patterns
- Auth flow and token management
- API client with shared envelope handling
- Testing infrastructure and helpers
- CI/CD pipeline
- Linting, formatting, and precommit checks
- Documentation (CLAUDE.md, AGENTS.md, STYLE.md, etc.)

## What Does NOT Belong in a Template

- Domain-specific models, pages, or business logic
- Product-specific API endpoints or routes
- Feature flags or product configuration
- Third-party integrations specific to one product

## Versioning

Templates are versioned independently. Product repos created from templates are not kept in sync — they diverge freely with domain logic. If a product repo develops a generally useful pattern, it may be upstreamed to the template as a new version.

## Shared Conventions

All templates share:

- Composition root pattern (single entry point reads environment)
- Zod for runtime validation (JS templates) / Ecto for schema validation (Elixir)
- Strict type checking (TypeScript strict mode / Dialyzer)
- Standard response envelope (`{ "data": ... }` / `{ "error": ... }`)
- Automated linting and formatting
- GitHub Actions CI
