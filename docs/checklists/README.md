# Checklists

Durable behavior that must keep working, one file per functional area (for example
`authentication.md`, `session-management.md`, `authorization.md`).

```text
docs/checklists/   WHAT MUST KEEP WORKING
test/ gait/ e2e/   HOW IT IS TESTED
evidence/          WHAT WAS ACTUALLY OBSERVED
```

A checklist item is a statement of behavior, not a test and not a record that anything was checked.

## Where items come from

When a change in `specs/<feature>/` is implemented and verified, the acceptance criteria that
describe lasting behavior are promoted here. Criteria that only describe the change itself (a
migration step, a one-time cleanup) are not.

## Using a checklist

- Before changing behavior in an area, read its checklist.
- If a change intentionally alters an item, update the item in the same change.
- If a checklist disagrees with the code, a spec or an ADR, raise the disagreement instead of
  picking a side.

See `.agents/harnesses/rules/project/acceptance-checklists.mdc`.
