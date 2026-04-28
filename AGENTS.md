This is an API-only web application written using the Phoenix web framework. There are no LiveView, HTML, or browser UI components.

## Project guidelines

- Reusable Phoenix API template for multi-tenant identity, authentication, and authorization. It contains auth and tenancy primitives, not product logic
- Elixir 1.19.5 + OTP 28.3.3 are pinned in `.tool-versions`
- Commit workflow: `.claude/instructions/commit_workflow.md`
- Dependabot PR merging: `.claude/instructions/dependabot_workflow.md`
- CI/CD setup: `.claude/instructions/ci_cd.md`
- Shared Elixir/Phoenix conventions (Tiny Inbox workspace only): `../.claude/instructions/elixir_phoenix_guidelines.md`
- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Run Elixir commands from the `elixir-api-core/` repo root. If `mix` or `erl` is missing in the shell, initialize `asdf` first with `source /usr/local/opt/asdf/libexec/asdf.sh`
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps
- All endpoints are JSON API endpoints under `/api/v1` (plus `/healthz` and `/readyz` at root)
- All API errors use the standard envelope: `{ "error": { "code": "...", "message": "...", "details": {} } }`
- OAuth provider is configurable via `Application.get_env(:elixir_api_core, :oauth_provider)` — use the mock in tests
- **Tenant safety**: use `ElixirApiCore.Repo.Scoped` helpers (`where_account/2`, `scoped_get/3`, `scoped_all/2`) for all account-scoped queries — never use raw `Repo.get` or `Repo.all` when the query should be account-scoped

## Commands

- First-time setup: `source /usr/local/opt/asdf/libexec/asdf.sh && mix setup`
- Dev server: `source /usr/local/opt/asdf/libexec/asdf.sh && mix phx.server`
- Test suite: `source /usr/local/opt/asdf/libexec/asdf.sh && mix test`
- Single test file: `source /usr/local/opt/asdf/libexec/asdf.sh && mix test test/elixir_api_core/auth/tokens_test.exs`
- Pre-commit: `source /usr/local/opt/asdf/libexec/asdf.sh && mix precommit`
- Local Postgres: `docker-compose up -d`

## Current Status

- `v0.2` complete
- Detailed design lives in `docs/ARCHITECTURE.md`
- Versioned task tracking lives in `CHANGELOG.md`
