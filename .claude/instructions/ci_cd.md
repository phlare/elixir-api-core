# CI/CD

## CI

`.github/workflows/ci.yml` runs on every PR and on push to `main`. Two jobs:

- **`test`** — spins up Postgres 16 as a service container, installs Elixir 1.19.5 / OTP 28.3.3 via `erlef/setup-beam@v1` (strict version match), `mix deps.get`, `mix format --check-formatted`, `mix test`.
- **`openapi`** — `stoplightio/spectral-action` lints `priv/openapi/*.yaml`. On PRs, `oasdiff/oasdiff-action/breaking` compares the PR's spec against the base branch (skipped when the base branch has no spec yet).

## CD

No deploy job. This is a template — downstream product repos wire up their own CD.

## When forking this template into a product service

Append a `deploy` job to `ci.yml` gated on `needs: [test]` and a push-to-a-specific-branch condition. Typical shape for a Fly-hosted service:

```yaml
deploy:
  needs: [test]
  if: github.event_name == 'push' && github.ref == 'refs/heads/develop'
  runs-on: ubuntu-latest
  concurrency: deploy-group
  steps:
    - uses: actions/checkout@v6
    - uses: superfly/flyctl-actions/setup-flyctl@master
    - run: flyctl deploy --remote-only
      env:
        FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

Store the Fly token as the `FLY_API_TOKEN` repo secret. For other deploy targets (Render, a VM, Docker registry, etc.), swap out the last step — the gating pattern stays the same.
