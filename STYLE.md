# Style Guide — Elixir API Core

Coding conventions observed in this codebase. Follow these when contributing.

---

## Module Structure

- One module per file, file path mirrors module name (`auth/tokens.ex` → `ElixirApiCore.Auth.Tokens`)
- Business logic in contexts: `Accounts`, `Auth`, `Audit`
- Web layer in `ElixirApiCoreWeb.*` (controllers, plugs, router)
- Schemas live under their context directory (`accounts/user.ex`, `auth/refresh_token.ex`)

**Module header order:**
1. `use` / `import` / `alias`
2. Module attributes (`@valid_roles`, `@min_password_length`)
3. Type definitions (`@type`, `@spec`)
4. Public functions
5. Private helpers

**Alias conventions:**
- One alias per line, alphabetical within namespace groups
- `import Ecto.Query, warn: false` for query modules

## Naming

- Functions: `snake_case`, descriptive verbs (`create_account`, `rotate_refresh_token`)
- Predicates end with `?`: `enabled?/0`, `demoting_last_owner?/2`
- No abbreviations in public APIs: `hash_password` not `pwd_hash`
- Error atoms are semantic and specific: `:invalid_refresh_token`, `:last_owner_required` (not `:error` or `:failed`)
- Module attributes for constants: `@valid_roles ~w(owner admin member)`

## Error Handling

**All public functions return `{:ok, result}` or `{:error, reason}` tuples.**

`with/1` chains for sequential validation:
```elixir
with {:ok, user} <- get_user_by_email(email),
     :ok <- verify_user_password(user, password) do
  {:ok, result}
end
```

Transaction rollbacks use semantic atoms:
```elixir
Repo.transaction(fn ->
  case condition do
    nil -> Repo.rollback(:invalid_refresh_token)
    result -> result
  end
end)
```

Normalization functions translate transaction results to clean tuples:
```elixir
defp normalize_rotate_result({:ok, {:refresh_token_reuse_detected, _}}),
  do: {:error, :refresh_token_reuse_detected}
defp normalize_rotate_result({:ok, %{} = result}), do: {:ok, result}
```

## Configuration

Modules wrap `Application.get_env` with a private `config/2` helper:
```elixir
defp config(key, default) do
  :elixir_api_core
  |> Application.get_env(__MODULE__, [])
  |> Keyword.get(key, default)
end
```

Fail-fast validation runs at boot for production-critical config.

## Ecto

**Changeset pipeline order:** cast → normalize → validate_required → validators → constraints

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :display_name])
  |> normalize_email()
  |> validate_required([:email])
  |> validate_format(:email, ~r/.../)
  |> validate_length(:email, max: 320)
  |> unique_constraint(:email, name: :users_email_lower_index)
end
```

- All schemas use `binary_id` primary keys
- Timestamps use `:utc_datetime`
- Sensitive fields use `redact: true`
- Enum fields use `Ecto.Enum` with a module attribute for values

## Controllers

- `action_fallback ElixirApiCoreWeb.FallbackController` on every controller
- Actions use `with/1` — success renders, errors fall through to fallback
- Success responses: `%{data: %{...}}`
- Error responses: `%{error: %{code: "...", message: "...", details: %{}}}`
- JSON serialization helpers are private functions at the bottom: `user_json/1`, `account_json/1`

## Tests

- `DataCase` (async: true) for DB tests, `ConnCase` (async: true) for controller tests
- `async: false` only when shared state requires it (ETS, Application env)
- `describe` blocks group related tests, no nesting
- Fixtures use `Map.get_lazy` for optional associations
- Assert on pattern match: `assert {:ok, result} = ...`
- Use `errors_on/1` for changeset assertions

## Guards & Specs

- Guard clauses on public functions for type safety: `when is_binary(user_id)`
- `@spec` used selectively on pure utility functions, not on all functions
- `@type` for public types referenced across modules

## Comments

- Comments explain *why*, not *what*
- No comments on obvious pipelines or pattern matches
- Architectural justifications get multi-line comments (e.g., locking strategy)

## DateTime

- Always `DateTime.utc_now()`, never local time
- Truncate to seconds: `DateTime.truncate(:second)`
- Compare with `DateTime.compare/2`, not operators
- Tests inject time via `opts`: `issue_access_token(id, id, :owner, now: ~U[...])`

## Tenant Safety

Use `ElixirApiCore.Repo.Scoped` for all account-scoped queries:
```elixir
import ElixirApiCore.Repo.Scoped

# Filter any queryable by account
Membership |> where_account(account_id) |> Repo.all()

# Scoped fetch by primary key (returns nil if wrong account)
scoped_get(Membership, id, account_id)

# Scoped fetch that raises on miss
scoped_get!(Membership, id, account_id)
```

- Guards on `account_id` (`when is_binary(account_id)`) prevent nil from slipping through
- Queries that are legitimately unscoped (user lookup by email, token lookup by hash) use `Repo` directly
- The `RequireAccountScope` plug in the `:authenticated` pipeline halts if `current_account_id` is missing
- Use `setup_tenant_pair/0` in tests to create two isolated tenant contexts and assert no cross-tenant leakage

## Workers (Oban)

- `use Oban.Worker, queue: :queue_name`
- `@impl Oban.Worker` on `perform/1`
- Return `:ok` for success
- `require Logger` before using `Logger.info/1`

## Audit

Side effects use a `with_audit/2` wrapper that logs on success and passes through errors:
```elixir
|> with_audit(fn data ->
  %{action: "user.registered", actor_id: data.user.id, ...}
end)
```
