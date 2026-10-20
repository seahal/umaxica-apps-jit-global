# Chronicle Polymorphic References Give NULL a Meaning

Recorded 2026-10-20. Status: backlog. The user classified this as an implementation defect to be
handled in a later audit; no change has been made.

## Problem

`Chronicle` declares `belongs_to :actor, polymorphic: true, optional: true` and
`belongs_to :subject, polymorphic: true, optional: true` (`app/models/chronicle.rb`). The
`chronicles` table in `db/chronicle_structure.sql` backs them with nullable `actor_type`/`actor_id`
and `subject_type`/`subject_id` columns, indexed but without foreign keys.

A NULL pair currently means "no actor" or "no subject". For example,
`app/jobs/passkey_audit_delivery_job.rb` creates chronicles without either, while
`lib/tasks/operator_capabilities.rake`, `app/controllers/concerns/org_administrative_audit.rb` and
`Chronicle.capture` callers pass various records. This conflicts with the AGENTS.md rule that
database NULL must not encode a state.

## Observations

- Referenced records live in other databases than `chronicle`, so a database foreign key cannot
  protect these references.
- No model declares `as: :actor` or `as: :subject`; rails-erd reports
  `Ignoring invalid association :subject on Chronicle (polymorphic interface Subject does not exist)`.
  The warning itself is a diagram limitation, not the defect.

## Audit scope

- Inventory the actor and subject types actually written, and the call paths that omit them.
- Decide an explicit representation for "no actor/subject" (NOT NULL columns with an explicit kind,
  a reference table, or separate record types) and whether polymorphism is kept.
- Check the impact on audit history: existing rows must be preserved
  (`adr/application-logging-boundary.md`).
