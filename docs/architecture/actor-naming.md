# Actor Naming

## Purpose

This document records current authenticated actor names for controllers, current context, tokens,
policies, and tests. The `com` surface is public and has no authenticated actor.

## Surface Actors

| Surface | Authenticated actor | Runtime actor type | Current helper     | Policy           | Status  |
| ------- | ------------------- | ------------------ | ------------------ | ---------------- | ------- |
| `app`   | `Client`            | `client`           | `current_client`   | `ClientPolicy`   | Current |
| `org`   | `Operator`          | `operator`         | `current_operator` | `OperatorPolicy` | Current |

## Current Migration State

The authenticated actor naming migration is complete at the runtime boundary. The accepted decisions
are:

- `app`: `User` was renamed to `Client`.
- `org`: `Staff` was renamed to `Operator`.
- The earlier `Customer` to `Visitor` rename applied to the former authenticated `com` actor. That
  actor and its sign-in surface are retired; `Visitor` is not a current authentication actor.

The `app` authenticated actor is `Client`. Actor-owned credential, preference, ticket, signal,
occurrence, and chronicle models use Rails-conventional table names such as `clients` and
`client_*`.

For `org`, the authenticated actor is `Operator`. The actor model now uses the conventional
`operators` table, and actor-owned models use `operator_*` table names.

The org-principal workspace account linked to the authenticated `Operator` is
`OperatorWorkspaceAccount`, backed by the `org_zenith.operator_workspace_accounts` table.
`OperatorAccount` is reserved for the org RP account in `org_zenith.operator_accounts`.

## Rules

- Do not introduce `Staff` runtime compatibility constants, helpers, policies, params, or JWT actor
  claims.
- Do not introduce `User` runtime compatibility constants, helpers, policies, params, or JWT actor
  claims for the `app` authenticated actor.
- Use `current_client`, `authenticate_client!`, `client?`, and `ClientPolicy` for `app`
  authenticated flows.
- Use JWT `act=client` for `app` actor tokens.
- Use `current_operator`, `authenticate_operator!`, `operator?`, and `OperatorPolicy` for `org`
  authenticated flows.
- Use JWT `act=operator` for `org` actor tokens.
- Do not add `self.table_name` compatibility overrides for old `user_*`, `staff_*`, or `customer_*`
  actor table names.

## Surface, Actor, and Message Vocabulary

`app`, `org`, and `com` are UI and routing surfaces. They are not actor types. Authenticated actors
are `Client` for `app` and `Operator` for `org`; the public `com` surface has no authenticated actor.
Unauthenticated traffic should be described as `guest` or `unauthenticated`, not as a `Visitor`.

Use the message names consistently:

- `Bulletin` is an actor-scoped, readable checkpoint or post-authentication message. Current
  implementations exist for `Client` and `Operator`; there is no `VisitorBulletin` contract.
- `Banner` is a surface-visible announcement. Existing banner tables are still actor-owned, so new
  code must not assume they are global announcements until that storage shape is explicitly changed.
- `Notice` is a transient controller/session/flash message unless a more specific model says
  otherwise.
- `Occurrence` is an audit, risk, or event record. It is not a user-facing notice or bulletin.

## Related Decisions

- `adr/app-actor-client-naming.md`
- `adr/org-actor-operator-naming.md`
- `adr/com-actor-visitor-naming.md`
