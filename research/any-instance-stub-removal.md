# Any Instance Stub Removal Note

This note records the removal of controller `any_instance.stub` usage from the test suite.

## Status

Completed on 2026-04-07.

## Context

The plan tracked a migration away from controller `any_instance.stub` usage in favor of:

- real request flow
- time helpers
- session setup
- service-layer verification

## Evidence

- `test/support/any_instance_stub.rb` is removed.
- The plan-listed tests no longer contain `any_instance.stub` usage.
- The target tests now rely on real request behavior, time helpers, or direct assertions.

## Validation

- Repository search for `any_instance.stub` returns no matches in the test tree.
- The plan-listed files no longer contain `any_instance` references.

## Consequences

- The migration can leave `plans/active/`.
- Future tests should avoid reintroducing controller-wide `any_instance.stub` patterns.
