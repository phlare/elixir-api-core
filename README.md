# Elixir API Core

[![CI](https://github.com/phlare/elixir-api-core/actions/workflows/ci.yml/badge.svg)](https://github.com/phlare/elixir-api-core/actions/workflows/ci.yml)
[![Elixir](https://img.shields.io/badge/Elixir-1.19.5-4B275F)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/OTP-28-blue)](https://www.erlang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-orange)](https://www.phoenixframework.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Multi-tenant identity, authentication, and authorization template for Phoenix APIs. This is a reusable foundation — it contains no product logic, only auth/tenancy/identity primitives.

## Requirements

- Elixir 1.19.5 + OTP 28 (pinned in `.tool-versions`)
- PostgreSQL 15+
- Docker (for local Postgres via docker-compose)

## Local Setup

```bash
# Start Postgres
docker-compose up -d

# Install deps, create DB, run migrations, seed
mix setup

# Run the dev server
mix phx.server
```

The API is available at `http://localhost:4000`.

## Running Tests

```bash
# Run all tests (auto-creates and migrates test DB)
mix test

# Run a single test file
mix test test/elixir_api_core/auth/tokens_test.exs

# Run a single test by line number
mix test test/elixir_api_core/auth/tokens_test.exs:42
```

## Pre-commit Checks

```bash
# Compile warnings, unused deps, formatting, tests
mix precommit
```

## API Endpoints

All auth/user endpoints are under `/api/v1`. Health endpoints are at the root.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/healthz` | No | Health check |
| GET | `/readyz` | No | Readiness check (DB) |
| POST | `/api/v1/auth/register` | No | Register with email/password |
| POST | `/api/v1/auth/login` | No | Login with email/password |
| POST | `/api/v1/auth/refresh` | No | Rotate refresh token |
| POST | `/api/v1/auth/logout` | No | Revoke refresh token |
| GET | `/api/v1/auth/google/start` | No | Get Google OAuth URL |
| GET | `/api/v1/auth/google/callback` | No | Handle Google OAuth callback |
| POST | `/api/v1/auth/switch_account` | Yes | Switch to another account |
| GET | `/api/v1/me` | Yes | Current user context |

See `priv/openapi/v1.yaml` for the full OpenAPI 3.1 spec.

## Architecture

- **Contexts**: `Accounts` (users, accounts, memberships), `Auth` (tokens, identities, OAuth, rate limiting), `Audit` (event log)
- **Token strategy**: Short-lived JWT access tokens (15 min) + opaque refresh tokens (30 day, rotated on use)
- **Multi-tenancy**: Users belong to accounts via memberships with roles (`owner | admin | member`)
- **Background jobs**: Oban with `default` and `maintenance` queues
- **Config validation**: Fail-fast on boot if required secrets are missing or unsafe defaults are used in production

See `docs/ARCHITECTURE.md` for detailed design and `docs/DECISIONS.md` for the decision log.

## Configuration

Dev/test use plaintext defaults in `config/config.exs`. Production requires these environment variables:

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection URL |
| `SECRET_KEY_BASE` | Phoenix secret (generate with `mix phx.gen.secret`) |
| `JWT_SECRET` | JWT signing secret (must not be the dev default) |
| `REFRESH_TOKEN_PEPPER` | Refresh token hashing pepper (must not be the dev default) |
| `PHX_HOST` | Production hostname |
| `PORT` | HTTP port (default: 4000) |

## Project Status

See `CHANGELOG.md` for the versioned task tracker.
