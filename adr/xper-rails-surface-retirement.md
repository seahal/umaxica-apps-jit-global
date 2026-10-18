# Xper Rails Surface Retirement

- Status: accepted
- Date: 2026-10-13
- Approval source: the user's confirmation of the retirement scope in DEC-064.

## Context

The Phase 0 Xper Rails surface provided independent placeholder roots and operational endpoints for
the `umaxica.{app,com,org}` and `xper.{app,com,org}.localhost` hosts. It did not provide an
Experience credential or persistence authority. The Phase 0 decision is recorded in
[`xper-phase-zero-bootstrap.md`](xper-phase-zero-bootstrap.md).

## Decision

- Retire the Xper Rails route draw and route file, controllers, views, layouts, stylesheet, frontend
  registrations, host slots, Rails host allowlist entries, and Xper environment plumbing.
- Serve no replacement Xper controller, redirect, or proxy. Requests to former Xper hosts remain
  subject to the existing unknown-host and framework health behavior.
- Change no models, database schemas or records, Preference behavior, authentication behavior, or
  Flipper records.
- Keep Edge and Cloudflare configuration outside this decision. Any Edge transfer is a separate
  change with its own boundary and evidence.
- Preserve the future Experience Web Push requirement. This decision implements no Web Push
  subscription, delivery, or credential behavior.

## Consequences

The Rails application no longer owns the Phase 0 Xper landing and operational endpoints. The three
public apex hosts and three private development aliases do not resolve to an Xper or another product
surface in Rails. The retired-host integration contract records this absence while retaining a
positive control for a current Base host.

The Phase 0 bootstrap and Auth/Xper workflow-deferral decisions remain available as history with
their superseded Rails-surface scope called out. Future Experience work must establish a new accepted
implementation boundary without treating the retired placeholder as a compatibility contract.

## Verification boundary

Rails routes, controllers, templates, styles, host slots, environment examples, and allowed hosts are
checked by static search and application boot. The retired-host test checks request routing and the
retained-host positive control. Compose aliases and variables are part of the same retirement scope;
their completion is recorded in the step evidence.
