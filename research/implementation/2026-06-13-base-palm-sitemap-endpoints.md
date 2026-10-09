# Base/Palm Sitemap Endpoint Implementation Notes

## Context

- Original plan/spec: add `sitemap.xml` wherever Base and Palm already expose `robots.txt`.
- Related decisions/docs/plans: `docs/architecture/controller-lifecycle.md`.
- Implementation date: 2026-06-13.

## Decisions Made During Implementation

- Decision: Base and Palm sitemap routes mirror the existing Acme/Sign inline route pattern.
  - Why: the route files do not currently define a reusable robots/sitemap route concern.
  - Alternatives considered: adding a new route concern, rejected because the requested change only
    needs six endpoints.
  - Follow-up needed: Palm now keeps the sitemap endpoint only on the app audience.

- Decision: Base and Palm sitemap controllers inherit each surface-local `BareController` and
  include `::Sitemap`.
  - Why: existing sitemap endpoints are public bare endpoints and the shared `Sitemap` concern owns
    the XML response headers.
  - Alternatives considered: using surface `ApplicationController`, rejected because public sitemap
    endpoints should not attach the authenticated lifecycle.
  - Follow-up needed: none.

## Deviations From Plan

- Change: The active surface plan originally mentioned Base/Palm root, health, and robots only.
  - Why: the current implementation request explicitly extends public file parity to `sitemap.xml`.
  - Risk: low; this follows existing Acme/Sign sitemap behavior and returns an empty sitemap XML
    document.
  - Follow-up: promote to stable docs only if public Base/Palm sitemap behavior needs permanent
    documentation.

## Review Notes

- Tests run:
- `bin/rails test test/controllers/public_robots_routing_test.rb`
- `bin/rails test test/controllers/controller_base_inheritance_test.rb`
- Tests not run: full suite.
- Documentation promotion needed: none currently.

## 2026-06-14 Update

Palm `com` and `org` endpoints were removed after the product decision that native clients are only
planned for the `app` audience. Base remains an app/com/org triple; Palm sitemap behavior is now
app-only.
