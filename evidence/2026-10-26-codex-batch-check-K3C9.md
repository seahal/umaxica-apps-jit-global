# Check of the 2026-10-25 Codex batch (scheduled review)

Date: 2026-10-26. Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`; worktree dirty (`git status --porcelain`: 811
paths), and the uncommitted changes affect every result below.

## Task status at check time

| Task | Evidence | State |
|---|---|---|
| i18n parity repair | `2026-10-25-i18n-parity-repair-P4R7.md` | Done, except the CI step: `.github/workflows/ci.yml` was on a read-only mount for Codex and still runs `i18n-tasks unused` |
| WU-20 Passkey acceptance | `2026-10-26-wu20-passkey-acceptance-W20A.md` | Done except A20-9 (Employee Number source undefined; code selects by `Operator.public_id`) |
| WU-30 Step-Up consumption | none | Not started (no file modified in the last hour; no Codex test process) |
| WU-38 stuck-registration report | none | Not started |
| WU-43 rename / WU-26 inputs | none | Not started |

## Review notes (reading only)

- i18n: production sets `raise_on_missing_translations = false`; the initializer logs key and locale
  only; no cross-language fallback. Production behavior was not exercised (runner could not boot
  without `BASE_SERVICE_URL`).
- WU-20: production changes are the resolver's verified/finalized/unexpired requirement, a
  `userHandle` check (`Webauthn::AssertionVerifier.verify_user_handle!`, length check plus
  `secure_compare`), and invalid-admission rendering. Timing sample: median difference +0.054 ms,
  p95 +0.901 ms (local test process).

## Full suite

`bin/rails test`: 18,331 runs, 152,933 assertions, 186 failures, 268 errors (454 problems), 0 skips.
Previous run (2026-10-25, after the first i18n change): 18,312 runs, 190 failures, 336 errors (526).
`MissingTranslationData`: 0 (was 35). Files with problems: 108 (was 116); no file newly failing;
15 files no longer failing.
