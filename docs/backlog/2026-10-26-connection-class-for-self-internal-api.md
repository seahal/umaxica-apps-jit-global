# `connection_class_for_self` is an internal Rails API

Status: Open (owner, 2026-10-26). Not part of the current cycle.

About 100 call sites choose a database role with `Model.connection_class_for_self.connected_to(...)`.
`ActiveRecord::Base.connection_class_for_self` is marked `# :nodoc:` in Rails
(`activerecord/lib/active_record/core.rb`): it walks superclasses to the class that declared
`connects_to`, and Rails itself uses it for role and shard resolution, but it carries no
compatibility promise. A removal would fail loudly (`NoMethodError`), not silently.

The owner accepted its use. Do not use `Model.superclass.connected_to` instead: it silently picks
the wrong class when the inheritance depth changes.

## When picked up

- Gather the call sites behind one application method (for example
  `ApplicationRecord.writing_connection_owner`) so a Rails change is a one-line fix.
- On every Rails upgrade, check that `connection_class_for_self` still exists and behaves the same.
