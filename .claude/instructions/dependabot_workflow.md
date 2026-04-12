# Dependabot PR Workflow

When merging dependabot PRs, follow this sequence for each PR:

1. Check out the PR branch
2. Run `mix deps.get` to regenerate `mix.lock`
3. Run `mix precommit`
4. Commit updated lockfile and push
5. Wait for CI to pass, then merge with `--merge` (never squash)

After all PRs for a repo are merged:

6. Switch back to main/develop and pull
7. Run `git fetch --prune` to clean up stale remote-tracking branches
8. Delete local dependabot branches: `git branch | grep dependabot | xargs git branch -D`
9. Verify no stale refs remain: `git branch -r | grep dependabot`

Notes:
- GitHub auto-deletes merged branches but there can be a short delay — if a remote ref survives the first prune, try again after a few seconds.
- Some repos may not label dependabot PRs with "dependencies" — always list all PRs, not just labeled ones.
- If a PR has merge conflicts after earlier merges, merge develop/main into the PR branch, then run `mix deps.get` again.
