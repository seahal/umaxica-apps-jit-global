# Frozen string directives in bin/ and GitHub Actions wiring (AT-039)

- Commit: `297addaed7333ef05f00059f64af08b579227e18` on `feature`, with uncommitted changes to
  `.github/workflows/ci.yml` and ten `bin/` binstubs that are the subject of this record.
- Who: the edits were made outside the development container by a separate Claude Code session,
  because `bin/` and `.github/` are read-only mounts inside it. Verification below was run inside
  the development container by Claude Opus 5.5 (claude-opus-5-5).
- Context: the 22 scripts removed in `45ed455ca`, including the isolated-fleet scripts, were removed
  intentionally (user confirmation, 2026-10-15) and were not restored.

## Change

- `bin/brakeman`, `bin/bundler-audit`, `bin/ci`, `bin/jobs`, `bin/kamal`, `bin/rails`, `bin/rake`,
  `bin/rubocop`, `bin/setup`, `bin/thrust`: `# frozen_string_literal: true` inserted on line 2,
  directly after the unchanged `#!/usr/bin/env ruby` shebang. Modes stay `-rwxr-xr-x`. `bin/dev` and
  `bin/setup-diagnostic-env` (shell) and `bin/vite` (already compliant) are unchanged.
- `.github/workflows/ci.yml`, job `lint-ruby`: two steps between "Run RuboCop" and "Run ERB Lint",
  running the same commands as `config/ci.rb`.
- `git diff --stat`: 11 files, 16 insertions, no other path changed.

## Verification inside the container

| Command                                                                                                                                                | Result                                                                                                                           |
| ------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| `ruby scripts/check_frozen_string_literal_directives.rb`                                                                                               | `frozen_string_directive_check_ok=6771`, exit 0                                                                                  |
| `bundle exec rubocop --config .rubocop_frozen_string_literal.yml --only Style/FrozenStringLiteralComment,Style/DisableCopsWithinSourceCodeDirective .` | 6,771 files, no offenses, exit 0                                                                                                 |
| `bin/rails runner 'puts :boot_ok'`                                                                                                                     | `boot_ok`                                                                                                                        |
| `bin/rake -T`                                                                                                                                          | lists tasks                                                                                                                      |
| `head -3` on each binstub; `ls -l bin`                                                                                                                 | shebang, then directive; modes unchanged                                                                                         |
| `ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml")'`                                                                                          | parses                                                                                                                           |
| `actionlint .github/workflows/ci.yml`                                                                                                                  | exit 1, only `runner-label` findings for the existing `ubuntu-slim` label on lines 44, 95, 277 and 344; nothing on the new steps |

The repository RuboCop configuration excludes `bin/**/*` (`bundle exec rubocop --list-target-files`
lists no `bin/` file), so the default `bin/rubocop` run is unaffected. Forcing the default
configuration onto the ten binstubs reports 18 style offenses (mostly
`Layout/EmptyLineAfterMagicComment`); they are outside the configured scope and were not changed.

## Not verified

- The new GitHub Actions steps were not executed on GitHub; no push was made.
- Migration replay from scratch for AT-039 needs the isolated fleet, which no longer exists, so that
  part of AT-039 remains BLOCKED. The directive and detection parts are satisfied.
