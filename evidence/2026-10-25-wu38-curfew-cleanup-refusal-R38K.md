# WU-38: curfew cleanup of unfinished registrations and the D-135 refusal (D-176)

- Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`, with extensive uncommitted work by this cycle and other agents in the worktree.
  WU-24e (Flow-first cleanup), WU-05 and WU-34 (D-128 Visitor statuses) are present there and are
  prerequisites of these results.
- Contract: `two.md` "WU-38", 6.2 F-1, D-126 (2), D-131, D-135, D-176. No migration.

## Changes

- New `app/queries/sign_up_contact_hold_query.rb`: a destination is held when a contact of the same
  surface has the same digest, is not `DELETED`, and its owner is in
  `UNFINISHED_REGISTRATION_STATUS_IDS`. Raises `ArgumentError` without a digest.
- The check runs under the destination's `SignUpEmailPendingGuard` advisory lock (principal DB) in
  APP email (`process_email_registration_under_lock`), COM email (`initiate_visitor_email_verification!`)
  and `TelephoneSignUpCandidateCreator` (new outcome `:contact_held`). Refusal: 422, the D-176 copy
  (`sign.{app,com}.registration.{email,telephone}.create.contact_held` in `config/locales/{ja,en}.yml`),
  nothing created. No Flow lock is taken by the check; cleanup keeps Flow → principal (F-1).
- Curfew trigger: no code change. Static reading and the tests below confirm that a Flow's
  `expires_at` is capped at its Binding's `curfew_at` and that `SignUpExpiryJob` (every 15 minutes,
  `config/recurring.yml`) expires it and runs `SignUpArtifactCleanup`.
- Updated tests that encoded the previous contract (independent candidates for one destination):
  the four "fresh sessions cannot distinguish pending and registered … sign-up" tests (APP/COM email
  and telephone) now expect the second browser to be refused 422 for both destinations alike; two
  APP telephone tests now expect a refusal beside an unfinished (locked / OTP-verified) candidate.

## Executed checks

- Query: `test/queries/sign_up_contact_hold_query_test.rb` 7 runs, 0 F (written together with the
  query; no separate Red run).
- Red for the refusal: with the query forced to `false`, `test/integration/sign_up_contact_hold_refusal_test.rb`
  gave 5 runs, 4 failures (the four refusals); restored: 5 runs, 38 assertions, 0 F.
- Curfew: `test/jobs/sign_up_curfew_cleanup_test.rb` 5 runs, 18 assertions, 0 F on first run
  (characterization: cap equals curfew; curfew − 1 s still held; at curfew APP cleaned and free;
  curfew + 1 s COM cleaned and free; registered identity behind an expired Flow unchanged).
- Sign-up bundle (APP/COM up controllers, sign/up check controllers, sign-up operations, services,
  jobs, concurrency, integration, queries): 561 runs; compared by test name against the same run with
  the query forced to `false`. The only names failing only with the change were the two
  `SignUpPasskeyTerminationHttpTest` deadline cases (409 expected, 201 actual); that file then
  passed alone twice (5 runs, 0 F each) — a timing-sensitive case under load, not attributed to this
  change. All other failures in the bundle (Design D admission redirects, `css` for nil in sign-up
  check setup) failed identically without the change.
- Focused run after the test updates: up email/telephone controllers (APP/COM), refusal, curfew,
  query, expiry job, cleanup atomicity, candidate creator: 230 runs, 2240 assertions, 0 F.
- Lifecycle direct-write invariant and locale bundle tests: 20 runs, 0 F.
- `bundle exec rubocop` on the changed application files and new test files: no offenses.

## Not covered / open

- An unfinished registration whose Flow can never reach cleanup (Flow missing, or past
  `MAX_CLEANUP_ATTEMPTS`) keeps its contact held indefinitely; no orphan sweep exists.
- Residual disclosure accepted by D-135: the refusal reveals that some unfinished attempt holds the
  destination (not whether an account exists).
- No full-suite run; no HTTP journey from an abandoned real sign-up through the job to a new sign-up
  (the pieces are covered separately).

## Follow-up (2026-10-26, D-180)

The former detection gap is covered by the read-only APP/COM
`SignUpStuckRegistrationReportQuery` and the `RetentionPurgeJob` report event. The report detects
unfinished principals or pending contacts with no Flow and terminal Flows whose pending/failed
cleanup has reached `MAX_CLEANUP_ATTEMPTS`. It does not release or mutate any registration. The
runbook permits one operator-reviewed retry for a capped terminal Flow through the existing cleanup
operation. A non-completed terminal Flow is retained until cleanup completes so the capped case
remains diagnosable. A missing-Flow record still has no safe existing release path and remains held
for escalation; ORG's schema cannot express these cases. See
`evidence/2026-10-26-wu38-stuck-registration-report-S8J4.md` for implementation and verification.
