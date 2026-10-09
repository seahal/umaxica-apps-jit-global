# Repository knowledge and agent harness

Status: implementing
Blocker: the GitHub Actions workflow is read-only in this workspace; AC-6 remains partially open.
Accepted: 2026-10-09 (user approval in the implementation conversation)

## Purpose and scope

Make accepted change contracts, current documentation, institutional memory and observed evidence
unambiguous across coding-agent generations. Keep one shared instruction and Skill source with thin
vendor adapters. Small changes remain cheap; security and persistent-data changes retain their gates.

Local repository changes only. External services, GitHub issue contents, deployment, credentials,
local vendor settings and application behavior are outside this change. Preserve concurrent work.
The temporary root files `one.md` through `five.md` remain untouched; preserve their references.
Other temporary auth handoffs remain with their owners while concurrent implementation continues.

## Acceptance

- AC-1: Directory responsibilities and conflict handling have one current reference; research and
  historical observations cannot silently become current contracts.
- AC-2: The SDD lifecycle defines proportional documents, local acceptance IDs, closure, corrections
  and promotion without a second current system description.
- AC-3: Root routing preserves security, approval and test obligations; retained Skills have narrow
  triggers and no contradictory mandatory phase approvals or unrelated framework tutorials.
- AC-4: Claude uses the canonical instructions and individual Skill adapters; no hand-maintained
  vendor copies or shared local secrets/settings are introduced.
- AC-5: Durable checklist and risk documentation separate requirements, observations, risk response
  and risk status; missing human ownership is disclosed rather than invented.
- AC-6: A local structural checker and CI definition detect broken managed paths and adapter drift;
  meaningful negative probes establish failure behavior without adding environment unit tests.
- AC-7: Migration decisions and actual checks are recorded, including excluded or unverified runtime
  and model compatibility checks. Existing historical evidence remains unchanged.

## Verification boundary

Filesystem and structural compatibility can be verified locally. Invoking hosted agent models and
remote CI is excluded by the user's external-environment boundary. Their unverified status remains
explicit; local validation does not claim model adherence, deployment or authentication correctness.

## Acceptance disposition

- AC-1, AC-2: implemented in the knowledge architecture reference, spec lifecycle and owning READMEs.
- `AC-3`: shared router and eight focused Skills implemented; security/test obligations retained.
- `AC-4`: individual adapters and ignore boundaries verified locally; hosted runtime discovery is
  outside this change's verification scope and is not claimed.
- `AC-5`: durable checklists and a minimal risk register implemented with unassigned authority explicit.
- `AC-6`: local checker, failure probes and local `bin/ci` integration complete. GitHub workflow
  integration remains blocked; `ci.patch` is prepared and validated in an isolated copy.
- `AC-7`: migration dispositions and implementation evidence retained.

See [migration dispositions](migration.md) and the linked implementation evidence in `tasks.md`.
The change remains open for the blocked CI integration; it is not marked verified or closed.
