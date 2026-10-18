# Direct Message Skeleton Retirement Implementation Notes

## Context

- Original plan/spec: retire `config/routes/line.rb` and related direct-message skeleton.
- Related ADR/docs/plans:
  - `docs/architecture/regional-content.md`
  - `adr/split-into-regional-and-global-repos.md`
  - `plans/backlog/direct-message-telecom-compliance-plan.md`
- Implementation date: 2026-06-03

## Decisions Made During Implementation

- Decision: remove the empty `line` route entry point and the `DirectMessageThread` model skeleton.
  - Why: current stable docs classify direct-message behavior as regional `line` work, while the
    route file exposed no concrete application routes.
  - Alternatives considered: keeping the empty route file as a future placeholder. Rejected because
    it conflicts with the repository boundary and creates local product intent without behavior.
  - Follow-up needed: remove the `message` database connection in a later stage after the drop
    migration has run in deployed environments.
- Decision: use a reversible `db/messages_migrate` migration to drop `direct_message_threads`.
  - Why: the user explicitly approved dropping the direct-message skeleton, including DB state, and
    migration rules require a reversible migration plan for destructive changes.
  - Alternatives considered: deleting `db/messages_migrate` and `message_structure.sql` immediately.
    Rejected because deployed environments still need the drop migration before connection removal.
  - Follow-up needed: completed later on 2026-06-03 by deleting `MessageRecord`, the `message` /
    `message_replica` database config blocks, `db/messages_migrate`, and `db/message_structure.sql`.

## Deviations From Plan

- Change: `bin/rails db:migrate:reset DATABASE=message` reset all configured development and test
  databases instead of only the message database.
  - Why: this Rails task did not honor the attempted `DATABASE=message` narrowing in this app.
  - Risk: local development and test databases were rebuilt from migrations. No repository files
    outside `db/message_structure.sql` are intended to keep schema-dump changes from that command.
  - Follow-up: use the app's exact multi-database task support, if any, before attempting a narrowed
    reset in future work.

## Review Notes

- Tests run:
  - `bin/rails routes -g line`
  - `RAILS_ENV=test bin/rails db:migrate:message`
  - `RAILS_ENV=test bin/rails db:migrate:redo:message VERSION=20260603021000`
  - `RAILS_ENV=test bin/rails db:migrate`
  - `bin/rails test test/config/routing_entrypoints_test.rb`
- Tests not run:
  - `bin/rails db:verify_no_schema_drift` did not pass because clean schema generation also changes
    `db/chronicle_structure.sql`, which is unrelated to direct-message retirement. The generated
    `message_structure.sql` change was kept; the generated chronicle change was reverted.
- Documentation or ADR promotion needed:
  - No ADR update yet. If direct messaging is reintroduced, promote repository ownership and telecom
    compliance gates to an ADR or active plan first.
