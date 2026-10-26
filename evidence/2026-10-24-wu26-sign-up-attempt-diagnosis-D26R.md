# WU-26: read-only sign-up attempt diagnosis (D-82)

Commit: `ba570a0007b1d40eabe32990a34831317fd98a93`, with this cycle's uncommitted changes in the
worktree (WU-24 E1 binding columns are required by the report).

## Implemented

- `SignUpAttemptDiagnosisInventory.call(surface: :app | :com, flow_public_id:)`, in `app/queries`.
  It reads one section per owner database, each with its own `database_now` read time:
  - **OP:** Flow status, step, entry method and requirement names; principal id; issue, expiry
    and completion times; E1 Binding id. Binding purpose, `entry_intent`, `curfew_at`, redeemed and
    retired.
  - **Principal:** actor status, Security Mode and `login_allowed?`; contact counts by status;
    Passkey counts by status; External Identities (provider, released).
  - **Graph:** presence of the Identity row.
  - **Authority:** root tokens issued for the principal since the Flow started (count and statuses).
  - **Classification** (six.md C.2): `in_progress_without_principal`,
    `principal_committed_graph_missing_flow_open`, `principal_and_graph_committed_flow_open`,
    `completed_without_principal`, `complete`, `ended_without_principal`,
    `ended_with_authority_issued`, `flow_not_found`, `unclassified`.
- Every read uses `connected_to(role: :reading, prevent_writes: true)`. A call made inside an
  explicit writing-role scope raises `WritingRoleRefused` (A26-2).
- `bin/rails sign_up:diagnose SURFACE=app|com FLOW=<public id>` prints the report as JSON.

## Not covered

- Inputs other than the Flow public id: entry reference digest, principal id, provider + subject
  digest.
- OIDC transaction and result references, ceremony session state, the social Candidate, and the
  log/audit correlation section.
- These are left for when the diagnosis is first needed.

## Runs

- `bin/rails test test/queries/sign_up_attempt_diagnosis_inventory_test.rb`: 6 runs, 0 F. The cases
  are constructed partial states:
  - an open Flow without a principal;
  - a committed principal without a graph;
  - a completed Flow without a principal;
  - an unknown Flow;
  - the absence of the contact address, nonce digest and entry reference from the JSON;
  - a writing-role refusal.
- `bin/rails sign_up:diagnose SURFACE=app FLOW=does-not-exist` on development printed
  `{"surface":"app","flow":null,"classification":"flow_not_found"}`. The development database
  holds no sign-up Flow, so no real attempt was diagnosed.
- `rubocop` on the new files: no offenses.
