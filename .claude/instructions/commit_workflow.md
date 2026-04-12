# Commit Workflow

## Before Every Commit

Run the precommit script before staging and committing:

```bash
mix precommit
```

This runs compile warnings, unused deps, formatting, tests, and dialyzer. If it fails on formatting, fix with `mix format` and re-run. Do not commit until precommit passes.

## Commit Message Convention

Use conventional commit prefixes:

- `feat:` — new feature or capability
- `fix:` — bug fix
- `test:` — adding or updating tests (no production code changes)
- `docs:` — documentation only
- `deps:` — dependency updates
- `refactor:` — code change that neither fixes a bug nor adds a feature
- `chore:` — maintenance tasks (CI, config, tooling)

Keep the first line under 72 characters. Use the body for details.

## Merge Strategy

Always use `--merge` when merging PRs via `gh pr merge`. Never use `--squash`.
