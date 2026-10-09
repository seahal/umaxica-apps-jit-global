# GH-661: Activity and Behavior DB Role Separation — Cancelled

## Status

Cancelled. Implementation policy changed before execution.

## Context

Issue [#661](https://github.com/seahal/umaxica-apps-jit/issues/661) proposed:

- Creating a restricted runtime DB user for Rails log writes to the activity and behavior databases.
- Creating an elevated maintenance DB user or role for edit-level operations.
- Configuring Rails to use the restricted write user for normal log writes instead of a broad
  owner-level connection.

The activity and behavior tables themselves were already created through separate migrations and are
present in `db/activity_schema.rb` and `db/behavior_schema.rb`.

## Decision

The DB role separation work described in issue #661 was not implemented. The implementation policy
changed before execution began, and the team decided not to proceed with this approach.

The issue was closed without implementing the restricted write user or the elevated maintenance
role.

## Consequences

- The activity and behavior databases continue to use the default connection configuration.
- Future work on append-only hardening or retention jobs is not blocked by this decision, but the DB
  role separation question remains open if it is revisited under a different policy.
- No code, migration, or configuration changes were made for this issue.
