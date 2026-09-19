# Surface Database Connection Naming

**Status:** Accepted (2026-05-18)

## Context

The current database connection names mix several naming eras:

- runtime actor names or near-actor names such as `operator` and `visitor`
- historical single-word storage names such as `guest`, `mark`, and `symbol`
- broad domain names such as `notification`
- the former `setting` connection, which now needs to fit the same surface-role vocabulary

This makes the database boundary harder to read because the connection name does not consistently
say which surface owns the data or what role the data plays. It also risks confusion with runtime
actor names (`Client`, `Operator`, `Visitor`) and controller route vocabulary such as `token`.

The accepted actor database naming policy says physical database names should not simply mirror
runtime actor names. We now need a concrete connection-name vocabulary for the remaining database
cleanup.

## Decision

Use two-word database connection names for surface-owned databases:

- first word: surface (`app`, `org`, or `com`)
- second word: storage role (`principal`, `ticket`, `zenith`, `signal`, or `setting`)

The accepted target mapping is:

| Current connection | Target connection | Role                                                               |
| ------------------ | ----------------- | ------------------------------------------------------------------ |
| `principal`        | `app_principal`   | App authenticated principal, credentials, and principal-side state |
| `mark`             | `app_ticket`      | App login/session/OIDC ticket state                                |
| `resident`         | `app_zenith`      | App Zenith/RP-facing account and subject projection                |
| `operator`         | `org_principal`   | Org authenticated principal, credentials, and org-side state       |
| `token`            | `org_ticket`      | Org login/session/OIDC ticket state                                |
| `personnel`        | `org_zenith`      | Org Zenith/RP-facing account and subject projection                |
| `guest`            | `com_principal`   | Com authenticated principal, credentials, and contact/auth state   |
| `symbol`           | `com_ticket`      | Com login/session/OIDC ticket state                                |
| `visitor`          | `com_zenith`      | Com Zenith/RP-facing account and subject projection                |
| `setting`          | `com_setting`     | Com login-independent surface setting and preference state         |

The app and org surface preference families also use dedicated setting databases:

| Target connection | Role                                                       |
| ----------------- | ---------------------------------------------------------- |
| `app_setting`     | App login-independent surface setting and preference state |
| `org_setting`     | Org login-independent surface setting and preference state |

The `notification` connection is split by surface instead of renamed one-to-one:

| Current connection | Target connection | Tables                                          |
| ------------------ | ----------------- | ----------------------------------------------- |
| `notification`     | `app_signal`      | `user_notifications`, `member_notifications`    |
| `notification`     | `org_signal`      | `staff_notifications`, `operator_notifications` |
| `notification`     | `com_signal`      | `visitor_notifications`                         |

Each target also has the matching replica connection, for example `app_ticket_replica` and
`com_signal_replica`.

## Vocabulary

- `principal` means the surface-owned authenticated principal and its principal-side state.
- `ticket` means login/session/OIDC ticket persistence. The word intentionally avoids overloading
  controller and protocol route names that use `token`.
- `zenith` means the Zenith/RP-facing account, subject, and local projection layer used by the Acme
  RP side of the system.
- `signal` means the notification-origin database for email, web push, banners, and related delivery
  channels.
- `setting` means login-independent surface setting and preference state. Actor-local preference
  state stays with the matching principal database.

Infrastructure and cross-cutting database names that are not surface-owned are not renamed by this
decision:

- `cache`
- `queue`
- `storage`
- `search`
- `occurrence`
- `chronicle`
- `avatar`
- `primary`

## Consequences

- Database connection names become readable as `surface_role`.
- Runtime actor names remain separate from database connection names.
- `visitor` no longer collides with the `Visitor` runtime actor.
- `token` no longer collides with token controllers, token endpoints, or protocol token vocabulary.
- `notification` becomes three signal databases, so that notification-origin state can evolve per
  surface.
- The `notification` split is a data-placement migration, not only a connection rename.

## Migration Notes

Implementation is a separate migration task. It should update, at minimum:

- `config/database.yml` connection keys, physical database names, env vars, and credentials keys
- abstract record classes and `connects_to` declarations
- schema dump filenames
- migration directory names
- test assertions that inspect connection names
- docs that describe current runtime database placement

No production database or table should be dropped as part of the naming change. Any physical
database rename or copy must be handled by an explicit operational migration plan.

## Related

- `adr/actor-db-naming-policy.md`
- `adr/preference-soft-bubble-doctrine.md`
- `docs/architecture/database-boundaries.md`
