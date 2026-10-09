# Change specification

Use the smallest structure that records the accepted change:

- Status and acceptance authority/reference.
- Purpose, users, scope and exclusions.
- Observable acceptance with stable local AC IDs.
- Material risks, assumptions and unresolved decisions.
- Verification approach at the actual public boundaries.

Reference current commands, architecture and style guidance rather than copying them. Add a plan
for non-trivial dependencies and tasks for independently verifiable execution units. Define stronger
traceability for security/data changes, not a repository-wide numbering scheme. Record unavailable
historical inputs honestly; never reconstruct their acceptance IDs from guesses.
