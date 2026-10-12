# P3d retired proof reference inventory

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- Existing staged, unstaged and untracked changes were preserved. No reset, cleanup, commit,
  push, production or shared-database operation was performed.

## Static inventory

The repository-wide search was run for the retired identifier-owned proof/context names
`otp_private_key`, `otp_counter`, `otp_expires_at`, `sign_up_otp_context` and
`credential_registration_otp_context`, excluding generated structure dumps from the path list.
The path counts were:

```text
app:    15 paths
lib:     0 paths
config:  5 paths
test:   61 paths
db:     41 paths
```

The current `app/` references were classified as ceremony-owned `otp_expires_at` reads, explicit
adapter rejection of retired counter arguments, forbidden-claim/filter names, or a bounded
operator ceremony reference inventory. No identifier model exposes a retired proof writer,
reader, or lifecycle helper. `lib/` has no matching reference. `config/` references are
redaction/filter keys or historical locale labels. The `test/` references are retirement
contracts, negative adapter/serialization fixtures, public ceremony tests, or historical policy
coverage. The `db/` references are historical/additive ceremony migrations and the reversible
retirement migrations; applied migration history was not rewritten.

The disposable PostgreSQL catalog assertion in [`U4K6`](2026-10-12-p3d-schema-retirement-U4K6.md)
reported no retired columns in the six identifier tables and no matching non-internal constraint,
trigger or public function. This static inventory and catalog result do not authorize data
deletion, certify every transport consumer, or replace the focused and full test gates.

No application or schema source changed while producing this inventory. The latest full
Rails/Vitest Gate remains the applicable shared-worktree gate.
