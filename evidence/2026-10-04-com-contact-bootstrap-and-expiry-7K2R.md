# COM contact lifecycle, bootstrap history and challenge expiry

HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, 2026-10-04 UTC. Authentication edits and unrelated concurrent work were uncommitted. All Rails commands used owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, preparation limited to `codex_integrity_20261003auth6f3_app_ticket`, and one worker. No shared database rebuild was performed.

## Changes and reproduced failures

- Migrated COM Passkey controller tests away from artificial Auth login and local JWT/dynamic helpers to real opaque admission and actual signatures. Six cases cover success, refusal/replay, fixed cancellation, nonconsuming GET and untrusted scope/target parameters. GET exposed missing COM verification strings (6 tests, 31 assertions, 2 translation errors, seed 4377). Added only the required COM namespace keys to all four existing locale bundles. HTTP GET verifies both languages in both regions without changing attempt counts, deadlines or challenges: 6 tests, 72 assertions, seed 64897.
- Both legacy Cookie ChallengeStore consumption APIs accepted the exact integer expiry second. New nearest-representable before/at/after tests reproduced two failures (13 tests, 42 assertions, seed 58977). Consumption and expired-entry cleanup now reject/remove deadline equality. The challenge stays spent after refusal. This tightens the existing callers; it does not migrate their authoritative state to the database.
- COM email confirmation left old freshness and another session's pending ceremony intact. A canonical public Base-finalized test reproduced stale freshness after successful confirmation (seed 18876). The COM controller now explicitly calls CredentialSecurityTransition for email confirmation with other-root-session revocation disabled: freshness and unfinished ceremonies are invalidated, while current and other root sessions stay usable. Failed OTP verification retains the previous freshness. The shared hook comment now names explicit per-surface policies.
- VerificationBase's initial-registration exception used only a zero configured-method count. A revoked COM Passkey actor therefore created another contact despite failing the public bootstrap-history predicate (seed 57020). The guard now requires that same writer history predicate. HTTP coverage verifies that true first contact succeeds without freshness, verified Email becomes an Email OTP method and ends that exception, and revoked credential history produces 422 without creating an email or ticket.

The COM contact tests use a fixture Base login and synthetic credential evidence finalized by the real public Base operation, not a cryptographic proof. Passkey controller tests and the separately recorded ORG journey cover actual signatures. Ordinary request authentication gained no credential lookup; the history query is reached at an explicit bootstrap check.

## Executed gates

- Three Base email registration files, ORG Normal root journey and CredentialSecurityTransition: 70 tests, 368 assertions, green, seed 49583.
- Base bootstrap issuer, complete APP TOTP registration journey, COM email registration, COM Passkey controller and ChallengeStore: 41 tests, 355 assertions, green, seed 44746.
- RuboCop on the seven changed Ruby files: no offenses.
- `git diff --check`: passed.

These gates overlap and must not be added together as unique test coverage. The earlier 74-test gate preceded the bootstrap-history fix; the gates above cover the final Ruby changes. Existing APP/ORG email tests passing does not prove every protected operation. Browser checks remain user-owned. Live provider behavior, Passkey registration candidates, admitted credential management, atomic last-method removal and complete legacy retirement remain outstanding. Excluded OTP logging work was untouched.
