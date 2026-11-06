# WU-A3 binding state shape and local migration

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. At the start of this record the worktree had 156
unstaged files and 35 untracked files; there were no staged changes. Existing work was kept.

Implemented the approved App/Org Admission Binding lifecycle reference: `issued` (10), `attached`
(20), `base_confirmed` (30), `redeemed` (40), `retired` (90), and `switched` (91). Binding
predicates and transitions now use `status_id`; the old timestamp/session columns remain proof
facts. The Switch writer matches the exact admitted Auth session, changes the source binding to
`switched`, and creates the replacement inside the parent-locked Ticket transaction. The purger uses
the explicit terminal status to select the retained terminal timestamp. App/Org diagrams, transition
inventory, and the owner-approved binding amendment in the ADR describe this shape.

Applied the five A3 binding migrations to local development App/Org and local test App/Org only.
Before the test App retry, a migration failed because the test environment created the status
reference as UNLOGGED while the binding was LOGGED; PostgreSQL rolled that migration back. The
migrations now explicitly set the reference tables LOGGED. The subsequent test App and Org migration
commands completed successfully. No production or Neon database was accessed.

Read-only post-migration checks observed, for each of the four local databases:

- zero admission-binding rows and six reference rows;
- LOGGED status reference tables;
- validated status-fact constraints and status foreign keys;
- both new status-based active indexes present and both old timestamp-predicate indexes absent.

`git diff --check` and Ruby syntax checks for the changed A3 models, service/controller boundaries,
purger, and migrations passed. No Minitest or full suite was run. WU-A3 behavior and concurrency
acceptance remain unverified.

WU-A3 remains incomplete: `two.md` §3.6 also requires explicit reference-state storage for the Auth
Ceremony and OIDC parent axes. The current Auth Ceremony still derives lifecycle predicates from
timestamps and the OIDC parent still persists string status. Their proposed shapes and local row
inventory are in `plans/2026-11-01-wua3-coupled-state-shape-execution-ticket.md`; no migration for
those axes has been written or applied. Owner approval is pending.
