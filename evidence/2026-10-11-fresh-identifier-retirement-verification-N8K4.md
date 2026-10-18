# Fresh identifier retirement verification

HEAD: `6007f0562fca205ce5b592aa82261b9836277814`. The worktree contains uncommitted application,
tests, migrations, scripts and documentation; this is not a reproducible code-only commit or
independent acceptance. Work crossed the UTC date boundary into 2026-10-11.

## Fresh ownership and migration execution

The older `20261010p8b` fleet and its roles were preserved. For a new run `20261010p3d2`, read-only
preflight confirmed 20 absent database names and 12 absent HMAC role names. Twenty new isolated
databases were created with the established owner/comment. A standalone helper failed at its
metadata query because it used Rails-only String#squish without loading Rails. Creation had
finished; read-only name/count/owner/comment/OID checks recovered the manifest without deletion,
recreation or adoption of another resource.

Owned manifest: `tmp/acceptance-isolated-20261010p3d2-primary.json`, host `primary`, workers 1. The
preparation list contains exactly its twenty physical database names.
`bundle exec rails db:test:prepare` followed by `bundle exec rails db:migrate` completed with
exit 0. All five new source-proof retirement migrations applied through normal history. Twelve
successful CREATE ROLE entries match the exact fresh role set; current OIDs/attributes and the
creation-log SHA-256 were recorded in the manifest. No existing cluster role was deleted or changed.

The existing isolated safety probe accepted all 38 configurations and rejected its six unsafe
inputs, exit 0. The six focused model/trigger/Email/Telephone issuer test files passed: 83 runs,
1,137 assertions, zero failures/errors/skips, exit 0.

## Non-NULL proof refusal

`bundle exec rails runner scripts/postgresql-identifier-context-retirement-rehearsal` passed eight
scenarios: both retired context columns on APP/COM Email/Telephone source tables. Each transaction
restores historical schema, inserts synthetic valid-shaped proof, attempts retirement in a
savepoint, observes explicit rejection, and checks unchanged proof/CHECKs/triggers. Outer rollback
leaves the retired schema unchanged. No proof or history is committed. The current CONTACT-5
criterion links this repeatable direct procedure.

Early procedure attempts failed on self-blocked schema lookup/idle-transaction timeout, omitted
semantic status and database-column aliases. Those synthetic transactions rolled back. Preparing
encrypted fixture values before DDL and using the real semantic status/attribute alias fixed the
procedure; the final eight-case run passed. No timeout or server permission was weakened.

## Role deletion refusal

The existing rebuild script now requires creation-record metadata and exact recorded role OIDs
before any database drop or role deletion, in addition to existing catalog/authority checks. A copy
of the new owned manifest with creation metadata removed was passed to the script: exit 1,
`role creation ownership metadata is required before role deletion`. The correct manifest passed the
safety probe again; a read-only catalog comparison confirmed all 12 recorded role OIDs unchanged. A
first inline comparison command had a quoting SyntaxError; the corrected literal-heredoc comparison
succeeded without changing catalog state.

RuboCop inspected both changed scripts: zero offenses. No Minitest/Vitest environment-construction
test was added. The normal Rails runner and synthetic domain-proof procedure were actually run. Full
Rails and Vitest gates on the fresh fleet completed successfully. Fresh-run cleanup and global
acceptance remain open. No production/shared operation or push occurred.

## Fresh full gate status

`bun run test` completed with exit 0: 99 files, 1,140 tests, 13.38 seconds. The full
`bundle exec rails test` completed with exit 0 against the new owned manifest with the complete
preparation scope: 15,013 runs, 127,316 assertions, zero failures/errors/skips, 977.526465 seconds.
The preceding old-fleet context gate had 15,013 runs and 127,312 assertions with no failures/errors;
the four additional assertions arise from strengthened source-state preservation checks. No failing
targets were suppressed or replaced by count-only comparison. The permanent rehearsal was rerun
after its final formatting corrections: all eight cases passed again, exit 0. Updated DB workflow
documents the creation metadata requirement and replacement-OID handling; current document diff
check passes. No subsequent application feature slice has begun.
