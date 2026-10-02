# CI trigger preparation for required checks

- Commit: `845f84b281663786c4d4e0f6473fcf3ab2040b74`.
- The user authorized removing CI path exclusions after reviewing the risk of
  documentation-only PRs waiting indefinitely for required checks.
- Removed both README.md/docs/** path exclusions from `.github/workflows/ci.yml`.
  Push branches remain develop/main; pull_request and workflow_dispatch remain enabled.
  Job definitions are unchanged. Existing unrelated worktree changes were preserved.
- `git diff --check -- .github/workflows/ci.yml` passed. Ruby YAML parsing and
  direct inspection of the event mappings confirmed unfiltered pull_request,
  push branches develop/main with no path filter, and workflow_dispatch.
- actionlint is not installed; GitHub Actions execution was not performed or rerun.
  No Minitest or Vitest configuration tests were added.
- `gh api repos/seahal/umaxica-apps-jit-global` still failed with
  `error connecting to api.github.com` in the agent environment.
- The prior user-run inspection identifies repository ruleset 9242634 as disabled,
  with no branch targets or bypass actors, and no effective rules on main. That is
  saved inspection evidence, not a fresh remote read in this turn.
- No GitHub settings were changed. The workflow change remains local and uncommitted;
  it must reach GitHub before the documentation-only PR issue is resolved remotely.
  Commit, push, PR creation, and merge remain outside the authorized scope.
- Required checks and App IDs must be reconciled with the workflow revision that
  reaches GitHub before enabling the ruleset. Existing recovery instructions remain
  at `/tmp/main-branch-protection-recovery/README.md`.
