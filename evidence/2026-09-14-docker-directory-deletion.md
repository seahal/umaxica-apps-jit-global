# 2026-09-14 `docker/` directory deletion

## Scope

The user deleted the legacy `docker/` directory, executing Step 3 of
`plans/analysis/docker-to-podman-directory-migration.md`. This record verifies what the deletion
removed and what still references the removed path. The deletion itself was performed by the user,
not in this session.

## Commands

```bash
ls -d docker podman
git status --porcelain | grep -cE "^.. docker/"
git status --porcelain | grep -cE "^.. podman/"
grep -rIn "docker/" --exclude-dir=.git --exclude-dir=node_modules . \
  | grep -v "docker\.io" | grep -v "syntax=docker/"
grep -rn "serve\.json" --exclude-dir=.git --exclude-dir=node_modules .
ls podman/
```

## Observed

- `docker/` is absent from the worktree; `podman/` is present and intact with 12 subdirectories
  (`alloy`, `base`, `core`, `grafana`, `pgadmin`, `pg-cron-poc`, `prometheus`, `psql-pub`,
  `psql-sub`, `remote-control`, `tempo`, `tools`). **No `podman/` file was deleted** — `git status`
  reports 23 deletions under `docker/` and 0 under `podman/`.
- The deletions are staged/unstaged working-tree changes; they are not yet committed. HEAD is
  `9d89b33e2`.
- No functional reference into `docker/` remains. The four surviving matches outside documentation
  are all exclusion rules, which now name a non-existent directory and are inert:

  | Location           | Line      | Purpose                             |
  | ------------------ | --------- | ----------------------------------- |
  | `.containerignore` | 129       | build-context exclusion             |
  | `.dockerignore`    | 143       | build-context exclusion             |
  | `.rubocop.yml`     | 1403      | `docker/**/*` lint exclusion        |
  | `.gitignore`       | 118 – 120 | `core/preferences` ignore rules     |

  `.rubocop/custom_exclusions.yml`, named by the Step 2 plan, does not exist in the worktree.
- `docker/tailscale/serve/serve.json` — the one file with no `podman/` counterpart, flagged by
  `evidence/2026-09-14-docker-directory-dependency-audit.md` — is gone and was **not** copied into
  `podman/`. Its content was `{"TCP":{"22":{"TCPForward":"core:2222"}}}`.
- Nothing mounts or reads that file. The only surviving mention of `serve.json` in the repository is
  the comment at `.devcontainer/remote-sshd-entrypoint.sh:174`, "replacing the sidecar's
  serve.json", above the line that now declares the same forward:
  `tailscale serve --bg --tcp=22 tcp://127.0.0.1:2222` (line 178).

## Assessment

The deletion is behavior-neutral for the container stack. The tailnet TCP/22 → sshd forward that
`serve.json` used to describe is declared by the `core` entrypoint and persisted in the
`tailscale-core-state` volume, so tailnet SSH does not depend on the removed file. The loss is the
ability to reconstruct the retired sidecar topology from the working tree; it remains recoverable
from history via `git show 9d89b33e2^:docker/tailscale/serve/serve.json`.

Recorded as a decision in `adr/container-support-directory-podman-only.md`.

## Not done

- No container was rebuilt, restarted, or started in this session. **The deletion is therefore
  verified by reference analysis only, not by a successful `podman compose` build or run.**
- `podman compose config` was not executed.
- The four stale exclusion entries were not removed.
- The deletions were not committed.
