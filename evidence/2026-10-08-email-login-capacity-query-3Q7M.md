# Email login capacity query

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted worktree changes affect results.

The APP/COM session-limit login journey fixtures still overwrote identifier HOTP after actual
Email issuance. Their initial command produced four errors (seed 2391). They now consume the
actual encrypted notifier code through the existing Auth verification route and continue on Base.
COM uses a distinct Base cookie jar and explicit original local admission/flow continuity; neutral
RP `/sign` starts OIDC and is not a local `entry_ref` issuance shortcut.

After fixture cutover, APP exposed a production lookup against the nonexistent raw `challenge`
column (three errors, seed 57958). Three existing APP/shared gate/limitations query sites now
compute the model-owned challenge digest and query `challenge_digest`; original actor/browser/
parent/deadline checks are unchanged. No raw challenge storage, fallback or alias was added.

Canonical session-limit State fixtures require explicit timestamps because their ReferenceRecord
disables automatic timestamps. Logout Kind/Status reference fixtures were also missing: the actual
selected-session revocation failed on `client_sign_out_flows` FK `fk_rails_39d731f429`, then exposed
an aborted SQL transaction. A temporary SQL diagnostic printed only the first exception line and
was removed after identifying that constraint. Local fixtures now establish their own canonical
references; global helpers and application reference-seeding behavior were not changed.

The normal command covering both promotion journey files, APP limitations controller and shared
session-limit gate passed 18 tests and 129 assertions, no failures/errors/skips (seed 14801).
Scoped RuboCop passed the three production query files and three affected test files. Full Rails,
full lint, cross-surface issuance/cooldown gates and final security/architecture gates remain pending.
