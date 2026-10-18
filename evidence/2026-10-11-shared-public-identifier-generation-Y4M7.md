# Shared standard opaque generation

HEAD: `122b460316d3168da381f096af74410586262984`. Application/query/task/test changes and unrelated
source-policy changes are uncommitted. All Rails checks use owned fleet `20261010p3d2`, workers 1
and the complete twenty-DB preparation list. No shared/production operation occurred.

This is an identity-preserving generator extraction under ID-2/ID-8, not a resource/session/JWT
lifecycle merge. PublicId.generate now fixes length 21 and explicitly non_secure=false through
installed Nanoid 2.0.0. Existing PublicId creation, three Preference models, ClientTotpCredential,
RpSession and NULL-only ORG Telephone backfill call the same mechanism. Existing callback timing,
values, collision discrimination and finite retry remain. Storage capacity/DB immutability and other
identifier contracts are not claimed complete.

Before extraction the seven relevant existing test files passed 98 runs, 369 assertions, zero
failures/errors/skips, 2.787217 seconds. New public-generation tests initially reported an absent
API (2 runs, 1 assertion, 1 failure/1 error). This is interface absence, not a newly discovered
production-behavior defect or environmental Red. The pure refactoring preserves the existing Green
behavior under nine.md's Refactor rule. Public tests additionally verify actual 21-character
URL-safe output and refusal of caller-selected size/alphabet/nonsecure mode; one output sample does
not establish random-quality/no-collision proof.

After extraction the ten-file generator/producer/collision set passed 129 runs, 551 assertions, zero
failures/errors/skips, 3.744276 seconds. The new AST invariant passed initially. A deliberately
created, previously absent owned app/values probe directly called Nanoid: the guard failed exactly
on that additional caller (1 run, 1 assertion, 1 failure, no errors/skips). The probe was deleted
after the completed negative run. The combined eleven-file set then passed 130 runs, 552 assertions,
zero failures/errors/skips, 3.701359 seconds. After Rails.root Pathname formatting was corrected,
the guard was rerun and passed 1 run/1 assertion, 0.830447 seconds. It scans direct named calls
under app/, not every alias, runtime dispatch or whole identifier classification. No broad
allowlist, assertion removal or UUID-name-based semantic verdict was introduced.

Final scoped RuboCop inspected ten files with zero offenses, exit 0. New assertion style preserves
the exact false Boolean contract. Oxfmt and git diff --check passed for owned prose. Actual source,
test and producer references are maintained in the existing identifier checklist/conventions; the
new project rule is routed from the existing root Task Rule Index. No second harness or runtime
identifier-management framework was created.

The existing knowledge checker was run with the four affected documentation/rule paths and exited 1
on its eight pre-existing adapter errors before document validation. Its global gate remains BLOCKED
and was not bypassed. Direct relative-link/probe-presence inspection was also performed; all fifteen
relative links resolved and the owned synthetic probe was absent; that limited check does not
replace the global checker. The document-only commit will not snapshot the dirty implementation.

Both Gate 2 commands started after local checks. Vitest exited 0: 99 files, 1,140 tests, 13.07
seconds. The initial Rails gate subsequently exited 1 after 974.070233 seconds: 15,028 runs, 127,458
assertions, one failure, zero errors/skips. ArchitectureBaselineTest reported only the resolved
PublicId ExplicitMethodVisibility offense still present in its generated inventory. This is a new
gate failure, not accepted as equivalent to the earlier zero-failure baseline.

At HEAD `310b77f7ef9f001371bb2a8c42a897db3411633a`, the existing public generator task
`bundle exec rake architecture:baseline` regenerated both inventory artifacts. Inspection showed
exactly one removal in each, the resolved PublicId visibility entry; no allowance was added or
increased and the Concern inclusion-hook debt remains.
`bundle exec ruby test/tooling/architecture_baseline_test.rb` then passed 3 runs, 2,748 assertions,
zero failures/errors/skips, 3.774391 seconds. Both full Gate 3 recovery commands were restarted:
`bundle exec rails test` against the same owned fleet and `bun run test`. Recovery Rails exited 0:
15,028 runs, 127,456 assertions, zero failures/errors/skips, 947.982606 seconds. Recovery Vitest
exited 0: 99 files, 1,140 tests, 13.46 seconds. The stale-baseline failure is resolved and both
required full suites are successful. No subsequent feature was edited during the pending gate.
Documentation-only commits occurred during the run, ending at
`444be21a5c25aa97f72bb47d2f20ec190068f21d` (the application and generated baseline remain
uncommitted). The later local adapter restoration record C8P4 supersedes the earlier
knowledge-checker availability observation; it does not rewrite that failed run as success.
Subsequent owned document commits and unrelated OTP documentation changes are present in the
worktree; the application state remains dirty. No application/test/migration commit, external
delivery, production change or push occurred.
