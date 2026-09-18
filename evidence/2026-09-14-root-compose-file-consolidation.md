# Root Compose file consolidation

Merged the repository-root Compose files down to two: `compose.yaml` and `compose.override.yaml`.
`.devcontainer/*` and the `fdw-poc` experiment overlays were left untouched.

## Change

- `compose.remote-access.yaml` and `compose.override.yaml.example` were deleted (`git rm`).
- `compose.override.yaml` is now a TRACKED file carrying the former remote-access `core` overlay
  under `profiles: [remote-access]`, its three named volumes (`tailscale-state`, `sshd-host-keys`,
  `sshd-run`), and the per-machine override guidance the `.example` used to hold.
- `/compose.override.yaml` was removed from `.gitignore`.

The profile is what preserves the opt-in contract. `compose.override.yaml` is auto-discovered by a
bare `podman compose`, so an unprofiled `core` overlay there would have replaced `core`'s command
with sshd on every plain `up`.

## Verification

Podman 3-way `config` resolution, run against the real files:

| Invocation                                                                                       | Expected                                  | Observed                                                                             |
| ------------------------------------------------------------------------------------------------ | ----------------------------------------- | ------------------------------------------------------------------------------------ |
| `podman compose config --services` (auto-discovers the override)                                 | `core` absent, 12 infrastructure services | `core` absent, 12 services                                                           |
| `-f compose.yaml -f .devcontainer/compose.yaml -f .devcontainer/compose.override.yml`            | `core` present, normal build              | `core` present                                                                       |
| `-f compose.yaml -f .devcontainer/compose.yaml -f compose.override.yaml --profile remote-access` | `core.command` = sshd entrypoint          | 1 match for `remote-sshd-entrypoint`; `tailscale-state`, `sshd-run` volumes resolved |

Compose takes the LAST value for `profiles:`, which is why `core` stays unprofiled on the Dev
Container path (that path never loads the root override) while the profile applies when the override
is passed last. This was confirmed first on a three-file scratch fixture, then on the real files.

Tooling guards, run with `ruby <file>` rather than `bin/rails test`: `bin/rails` could not boot in
this worktree because `Gemfile.lock` points at a `bundler/gems/rails-f3deab27b7b7` path that does
not exist (pre-existing, unrelated to this change). These guards are plain `Minitest::Test` with no
Rails dependency.

- `compose_local_override_optional_test.rb` — 13 runs, 58 assertions, 0 failures
- `compose_host_port_exposure_test.rb` — 5 runs, 12 assertions, 0 failures
- `compose_init_reaping_test.rb` — 2 runs, 3 assertions, 0 failures
- `compose_restart_policy_test.rb` — 4 runs, 89 assertions, 0 failures
- `compose_tmpfs_compatibility_test.rb` — 1 run, 0 failures
- `global_portability_contract_test.rb` — 0 failures

`compose_local_override_optional_test.rb` gained three guards replacing the now-wrong "the local
override is not tracked" assertion: the root holds exactly two Compose files, every service in the
root override is profile-gated, and `core` stays unprofiled in `.devcontainer/compose.yaml`.

`bash -n` passes on `.devcontainer/remote-access-preflight.sh`,
`.devcontainer/remote-sshd-entrypoint.sh`, and `bin/setup-dev-secrets`.

RuboCop was NOT run — it needs the same broken bundle.

## Not done

The `fdw-poc` overlays (`podman/fdw-poc/`, `docker/fdw-poc/`) were unchanged per scope. Noted while
reading them: both declare `depends_on: rustfs`, and `compose.yaml` no longer defines a `rustfs`
service, so those overlays were already stale. Followed up in
`evidence/2026-09-14-fdw-poc-artifact-removal.md`, which removed them.
