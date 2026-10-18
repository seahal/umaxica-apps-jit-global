# Owned Ruby Files Declare Frozen String Literals

## Status

Accepted. The planning record for this cycle states that the user accepted this decision on
2026-10-11; this document was written on 2026-10-13 and that date is carried over from the planning
record, not re-verified here.

This is a **target contract; the repository does not yet conform**. Writing this ADR changed no Ruby
file and no RuboCop configuration. It is the single authority for this topic: do not create a second
ADR, rule or plan that restates or varies it; amend this one.

Progress recorded on 2026-10-14: directives were added or repositioned in writable owned Ruby files,
and local CI now runs a leading-directive inventory before the scoped RuboCop check. The inventory
and cop still report ten missing directives in `bin/`; the `bin/` ZFS mount is read-only. The GitHub
Actions lint job also has not been updated because `.github/` is a separate read-only ZFS mount.
Migration replay was not run: the current database constraint permits only the standard development
and test databases, while this ADR requires an isolated disposable fleet for that check. The change
therefore remains incomplete. After the Passkey-slot test correction, the full standard Rails suite
was rerun: 15,256 runs, 128,994 assertions, 0 failures and 14 Avatar worker-receipt errors. No Strict
Loading errors appeared. This result does not clear the remaining directive, CI or migration gates.
See `evidence/2026-10-14-frozen-string-directives-followup-Q3M7.md` and
`evidence/2026-10-14-passkey-slot-standard-test-followup-C9R2.md`.

## Context

`# frozen_string_literal: true` makes every string literal in a file immutable. A literal that is
mutated by accident then raises at the point of the mistake instead of silently changing a value
shared with other callers. It also removes a per-evaluation allocation for each literal.

RuboCop already runs `Style/FrozenStringLiteralComment` with `EnforcedStyle: always`, so most of the
codebase carries the comment. The rule nevertheless has gaps. Measured at commit
`4828aeedd141b54163236672890799b9b01128c2` over tracked `*.rb`, `*.rake`, `*.ru`, `Rakefile`,
`Gemfile` and `bin/*`, 108 files lack the `true` directive:

| Group                            | Files | Why the cop did not catch them                                   |
| -------------------------------- | ----- | ---------------------------------------------------------------- |
| Migrations under `db/*_migrate/` | 84    | `.rubocop.yml` excludes `db/**/*_migrate/**/*.rb` from every cop |
| Executables under `bin/`         | 12    | `.rubocop.yml` excludes `bin/**/*` from every cop                |
| `config.ru`                      | 1     | not matched by the configured `Include` patterns                 |
| Empty test files                 | 11    | zero-byte files; the cop has nothing to inspect                  |

Two further weaknesses: the `always` style accepts `# frozen_string_literal: false`, and nothing
checks files that generators create after the fact.

## Decision

1. **Every Ruby file this repository owns begins with exactly one `# frozen_string_literal: true`
   directive**, placed where Ruby honours it: in the leading comment block before any code, after a
   shebang line when there is one. Other leading magic comments such as `# typed:` may precede or
   follow it as the existing files already do.
2. **"Owned" means authored and maintained here**: application code, tests, configuration,
   initializers, Rake tasks, `Rakefile`, `Gemfile`, `config.ru`, executables under `bin/`, scripts
   and every migration in every `db/*_migrate/` directory. It excludes third-party code: gems,
   `vendor/`, `node_modules/` and generated schema dumps.
3. **Migrations are included, applied ones too.** This is a narrow exception to the rule that an
   applied migration is not edited. The exception covers the directive line only. Migration
   versions, class names, schema operations and data operations do not change, and no migration is
   re-applied because of it.
4. **A real incompatibility may be repaired, narrowly.** If a file, including an applied migration,
   fails under frozen literals because it mutates a literal, the fix is an explicit mutable
   allocation at that site (`+""`, `String.new`, `.dup`). The fix preserves behavior. It is not
   permission to redesign the file.
5. **No global switch and no third-party patch.** Frozen literals are not enabled through `RUBYOPT`,
   `--enable-frozen-string-literal` or any process-wide setting, and no gem is patched to tolerate
   them. The directive is per file so that ownership stays visible in the file.
6. **RuboCop enforces the directive with `EnforcedStyle: always_true`** for every owned file. The
   blanket exclusions that currently hide migrations and `bin/` are narrowed for this cop, so the
   cop inspects them while other cops may stay excluded there. If the global exclusions cannot be
   narrowed for one cop, the check runs with its own configuration and invocation. Inline disabling
   of this cop is not used. Both the local CI entry point and the GitHub Actions lint job run it.
7. **Generated files conform before they are committed.** A generator template or post-generation
   step that produces a Ruby file without the directive is corrected at the source.
8. **This decision is not reversed file by file.** Removing the directive from an owned file, or
   setting it to `false`, requires amending this ADR.

## Verification

- Static: the cop reports no offense across all owned files, including the paths listed above. A
  deliberately wrong file (missing directive, `false`, directive below the first statement, inline
  disable) is rejected. This is observed by running the cop, not by a test whose subject is the
  RuboCop configuration.
- Runtime, migrations: every migration runs from scratch on an isolated disposable database fleet
  whose ownership and connection targets are verified
  (`scripts/postgresql-rebuild-isolated-test-fleet`). The ordinary development databases are not
  reset for this. Narrowing recorded on 2026-10-13: the first version of this ADR named a complete
  drop, create and migrate of the development databases as the method the user had approved; the
  method was then limited to the isolated fleet. The isolated fleet was not the only approved method
  from the start.
- Runtime, application: the existing test suite and a development boot pass with the directives in
  place.

A successful rebuild shows that migrations still load and run. It says nothing about business
behavior, which keeps its own tests.

## Consequences

- About one hundred files gain one line; most are migrations. The change to behavior is expected to
  be nil except where a literal was being mutated, which becomes an immediate, local error.
- The RuboCop configuration needs a scoped inclusion for this cop. Narrowing a blanket exclusion
  must not switch on unrelated cops for migrations or executables as a side effect.
- Applied migrations will differ textually from what was run in other environments by one comment
  line. Their effect is identical, and environments that already ran them are not affected.
- The eleven empty test files counted above were deleted on 2026-10-13 by user decision, ahead of
  the rest of the implementation. They contained no test. 97 files remain to be brought into
  conformance.

## Alternatives considered

- **Process-wide frozen literals.** Rejected: it would also freeze literals in third-party code that
  this repository does not own and cannot fix, and it hides the contract from the file.
- **Leave migrations out.** Rejected: migrations are owned Ruby that runs in every environment
  rebuild; excluding them keeps an unowned corner where the rule silently does not apply.
- **Keep `EnforcedStyle: always`.** Rejected: it accepts an explicit `false`.
- **Wait for a Ruby release that changes the default.** Rejected as a reason to do nothing: the
  directive is harmless under any default and states the intent now.
