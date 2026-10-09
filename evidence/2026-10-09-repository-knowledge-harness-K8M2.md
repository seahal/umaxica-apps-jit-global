# Repository knowledge and harness implementation checks

Date: 2026-10-09 (UTC)
Repository commit: `13f27059c874e607bbe246cdf532b832691012fa`
Branch: `feature`
Worktree: uncommitted documentation, shared Skills, adapters and checker changes affected these
results. Concurrent authentication-test and existing evidence edits were present and left untouched.
No application-test or authentication correctness claim is made.

Scope: [accepted local change](../specs/repository-knowledge-and-agent-harness/spec.md), AC-1 through
AC-7, with AC-6 partially blocked. [Migration dispositions](../specs/repository-knowledge-and-agent-harness/migration.md)
record retained temporary files and provenance handling.

## Observed checks

- `scripts/check-repository-knowledge` passed for the managed entry points, routed paths, eight
  shared Skills and eight individual Claude adapters. Explicit changed-document arguments also
  passed for relocated references and the owning spec after correcting duplicate criterion-definition
  formatting in its disposition section.
- The skill-creator `scripts/quick_validate.py` passed on all eight retained Skills. Shared Skill
  bodies total 10,945 bytes across eight Skills, versus 24 substantially larger workflow bodies
  before consolidation; this is file size, not a measured model-context saving.
- `bundle exec rubocop scripts/check-repository-knowledge config/ci.rb --format simple` passed:
  two files, no offenses. The first checker run exposed style offenses; they were corrected and
  the scoped lint was rerun. `ruby -c` passed for both edited Ruby files.
- 44 checks in a disposable local repository passed. Probes exercised baseline and `--base` diff
  operation; invalid/missing base and out-of-repository arguments; metadata mapping/name failures;
  description lengths 0/1/1023/1024/1025 and missing/null/numeric/whitespace sentinels; folder-name
  lengths 1/63/64/65 (zero-length folder is not representable); broken and copied adapters; missing
  routed and inline-link targets; all six spec statuses, invalid status and missing/duplicate IDs;
  evidence hash lengths 0/39/40/41, suffix lengths 3/4/5, invalid calendar date, and malformed then
  corrected newly committed evidence. Fixtures were removed afterwards; no Minitest/Vitest setup
  tests were introduced.
- `git apply --check specs/repository-knowledge-and-agent-harness/ci.patch` passed. In the disposable
  copy the patch applied, its workflow parsed with Ruby YAML, and the new step passed `bash -n`.
- `git check-ignore` confirmed Claude settings, local settings, worktrees and the pre-existing local
  vite-plus link remain ignored. Adapter target checks confirmed the retained shared Skill links.
- Installed version commands returned `codex-cli 0.162.0` and `2.1.295 (Claude Code)`. These commands
  do not establish actual instruction discovery or model behavior.
- SNS assessment navigation repaired 348 existing targets to relative links; 101 absent paths are
  explicitly historical citations. This was navigation repair, not a fresh domain implementation audit.
- `git diff --check` passed at the recorded checkpoint with these edits.

## Failed, blocked, and unverified

Writing `.github/workflows/ci.yml` failed with `OSError: [Errno 30] Read-only file system`. The actual
workflow remains unchanged; the patch is prepared but unapplied. Local `config/ci.rb` now runs the
checker first. Neither full `bin/ci` nor remote CI ran; they include unrelated application/database
and network work. `actionlint` was unavailable; YAML and shell checks do not replace it.

Rails, Vitest and Playwright suites were not run: this change modifies documentation and tooling,
not application behavior. No dependency install, live environment mutation, GitHub operation,
production action or hosted model invocation was performed. Cross-vendor behavioral pilot and
runtime discovery remain unverified. Ignored local hooks/settings remain unchanged and may still
contain the previously observed stale asynchronous auto-fix configuration.

The checker verifies structural properties, not semantic contract agreement, real approval authority,
remote links, Markdown anchors, all historical references or correctness of cited observations.
Risk ownership and acceptance authority remain explicitly unassigned where the existing ADR did not
identify them; no new risk acceptance was granted.
