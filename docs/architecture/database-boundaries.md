# Database Boundaries

> **Global / Regional ownership settled (2026-09-08):** `adr/global-regional-database-ownership.md`
> is the normative decision. `*_zenith`, `*_ticket`, `*_setting`, `*_signal`, `avatar`, and
> `publishing` are **Global-only**. `chronicle`, `occurrence`, `primary`, and `queue` exist as
> independent (never shared) databases in both Global and Regional. Regional owns one new
> application database. There is no `*_principal` regional-ready database; that role is retired. The
> `search` and `storage` reserved connections (zero migrations) are deletion candidates for the
> split.

> **Partially superseded by Identity Authority inversion:** Physical database names and table/model
> placement do not imply logical identity authority. `acme/www` is the Session, Token, Account,
> Preference, Authorization, and downstream-token Authority. `sign/id` is ceremony-only. Existing
> sign-side physical tables/models do not imply sign-side authority.

## Purpose

This document records the accepted database connection naming model for surface-owned data.

The current database boundary names are not the same thing as the future authority placement target.
See `docs/architecture/database-authority-placement.md` for the placement contract.

## Naming Model

Surface-owned database connections use `surface_role` names.

| Surface | Principal       | Ticket       | Zenith       | Signal       | Setting       |
| ------- | --------------- | ------------ | ------------ | ------------ | ------------- |
| `app`   | `app_principal` | `app_ticket` | `app_zenith` | `app_signal` | `app_setting` |
| `org`   | `org_principal` | `org_ticket` | `org_zenith` | `org_signal` | `org_setting` |
| `com`   | `com_principal` | `com_ticket` | `com_zenith` | `com_signal` | `com_setting` |

Role meanings:

- `principal`: retained connection key reserved for future regional-ready application data. Current
  semantic principal models use the matching `*_zenith` physical database.
- `ticket`: login/session/OIDC ticket persistence.
- `zenith`: Zenith/RP-facing account, identity binding, and local projection state.
- `signal`: notification-origin state for email, web push, banners, and related channels.
- `setting`: login-independent surface setting and preference state.

## Current Migration State

The implemented target mapping is:

| Current     | Target          |
| ----------- | --------------- |
| `principal` | `app_principal` |
| `mark`      | `app_ticket`    |
| `resident`  | `app_zenith`    |
| `operator`  | `org_principal` |
| `token`     | `org_ticket`    |
| `personnel` | `org_zenith`    |
| `guest`     | `com_principal` |
| `symbol`    | `com_ticket`    |
| `visitor`   | `com_zenith`    |
| `setting`   | `com_setting`   |

The session-side preference families use the surface setting databases:

| Target        | Tables                                |
| ------------- | ------------------------------------- |
| `app_setting` | `app_preferences`, `app_preference_*` |
| `org_setting` | `org_preferences`, `org_preference_*` |
| `com_setting` | `com_preferences`, `com_preference_*` |

The current `notification` connection will split into three surface signal databases:

| Target       | Tables                                         |
| ------------ | ---------------------------------------------- |
| `app_signal` | `client_notifications`, `member_notifications` |
| `org_signal` | `operator_notifications`                       |
| `com_signal` | `visitor_notifications`                        |

## Unchanged Cross-Cutting Databases

These database names remain independent cross-cutting or infrastructure boundaries:

- `primary` — Rails default database (`db/migrate`, dump `db/structure.sql`). Durable,
  low-frequency, application-wide configuration or metadata that does not have a strong domain,
  lifecycle, scaling, retention, isolation, or operational reason to own a dedicated database.
  Flipper currently uses it. It is not an indiscriminate catch-all: data with a meaningful
  independent ownership boundary stays in its dedicated database.
- `queue`
- `storage`
- `search`
- `occurrence`
- `chronicle`
- `avatar`

## Rules

- Do not introduce new surface-owned one-word connection names.
- Do not use runtime actor names as database connection names.
- Do not add new global authority data to `*_principal`; use the accepted authority-placement
  decision and keep `*_principal` reserved until a separate regional-ready placement decision.
- Keep table renames separate from connection-name work unless an explicit migration plan requires
  both.
- Keep login-independent surface settings in the matching `*_setting` database.
- Keep actor-local preferences in the matching `*_principal` database.

## Related

- `adr/surface-database-connection-naming.md`
- `adr/actor-db-naming-policy.md`
