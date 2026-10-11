# Authority Terminology Documentation Audit

Date: 2026-09-18 (UTC)

## Scope

This audit checked the current-tree architecture documentation against the adopted Persona and
Organization naming migration. It was limited to repository prose; it did not apply migrations,
change authority behavior, or change Avatar routes or authorization.

## Evidence

- Branch: `feature`
- Starting task HEAD: `22afe6b4cd5f00d73dd7c4e4b886406a666d6f9a`
- Pre-existing staged, unstaged, and untracked changes were present and were not modified.
- Current model evidence: `app/models/client_persona.rb` maps the physical `personas` table,
  `app/models/concerns/persona.rb` is the common interface, and
  `app/models/operator_organization.rb` maps the legacy `organizations` table.
- The inspected document was
  `docs/architecture/principal-zenith-membership-organization-placement.md`.

## Result

The document was corrected to:

- name `ClientPersona` and `OperatorOrganization` as the concrete current classes;
- describe `Persona` and `Organization` as common Ruby interfaces rather than persisted base models;
- record the existing `org_zenith` connection for the legacy `organizations` table;
- remove claims that `Member` or `OperatorWorkspaceAccount` include the retired `Account` concern;
- distinguish unrelated RP-account projections from the adopted Persona authority vocabulary.

The current URL policy audit remains documentation-only: no public Avatar handle route exists in the
Rails route tree, and no new `@` namespace or handle validator was introduced.

## Verification

Command:

```text
git diff --check
```

Result: passed.

Rails runtime and link tests were not run in this slice. The isolated PostgreSQL and Valkey services
required for the repository's Rails test boot were unavailable; this remains tracked by `CF-002` in
`conflict.md`.
