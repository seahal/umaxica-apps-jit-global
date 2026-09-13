# Preference Architecture

> **Partially superseded by Identity Authority inversion:** The preference vocabulary in this
> document remains useful only where it does not assign preference, settings, dashboard, or session
> authority to `sign/id`. `acme/www` is the Session, Token, Account, Preference, Authorization, and
> downstream-token Authority. `sign/id` is ceremony-only. Existing sign-side physical tables/models
> do not imply sign-side authority. Do not use this document to reintroduce sign-side sessions,
> refresh, preference, dashboard, account lifecycle, token issuance, logout, or step-up freshness.

## Purpose

The preference system has two different roles.

- `AppPreference`, `OrgPreference`, and `ComPreference` hold login-independent surface setting
  state.
- `UserPreference`, `OperatorPreference`, and `VisitorPreference` hold per-account local settings.

The system must keep these roles separate.

The database is the source of truth for both shared and local preference state. The Preference JWT
is a signed projection of that database state for runtime reads. Auth access tokens do not carry the
`prf` preference snapshot.

## JWT Projection Boundary

Current token projection is intentionally narrow.

| Data         | JWT projection                 | Current contract                                                                              |
| ------------ | ------------------------------ | --------------------------------------------------------------------------------------------- |
| Preference   | Preference JWT only            | DB source of truth projected into `preference_access`; auth access tokens do not carry `prf`. |
| Identity     | Auth/OIDC identity claims only | Credential, contact, verification, and lifecycle state remain DB-only.                        |
| Avatar       | None                           | Avatar selection and authority remain DB-only/session-row state.                              |
| Organization | None                           | Organization membership and role checks remain DB-only policy state.                          |
| Group        | None                           | Group membership and authorization remain DB-only policy state.                               |

OIDC ID token claims and auth access token claims are separate contracts. An ID token may describe
the authenticated subject for an RP. An auth access token may carry authentication/session facts for
the Rails authorization boundary. Neither token turns identity, avatar, organization, or group rows
into JWT-owned source-of-truth state.

Preference setting writes are exposed through the `sign` surfaces. `acme` and `jump` consume
preference state as read-only runtime context through `Actor.preferences`.

## URL Role Boundary

Preference, setting, and operational configuration routes have separate responsibilities:

- `/preference` is the login-independent preference boundary. It may be used before login, after
  logout, or while authenticated. It owns shared surface preference state such as language, region,
  timezone, theme, display options, and cookie consent.
- `/setting` is the signed-in user setting boundary. It owns account-local and security settings for
  the current actor, such as credentials, sessions, MFA, contact methods, notification settings, and
  withdrawal flows.
- `/configurator` is the operator-controlled configuration boundary. It owns settings an authorized
  operator manages for an organization, workspace, tenant, public surface, or managed runtime.

Do not move preference writes under `/setting` merely because the actor is authenticated. Do not
expose account settings through `/preference` merely because a settings page also displays
preference context. Do not mix operator-managed configuration with user self-service settings.

These URL roles are canonical for new documentation and route work. Existing plural `/settings`
routes are a compatibility gap and need a separate migration plan before route renaming.

## Scope

### Shared preference

Shared preference is the source of truth for login-independent surface preference state.

- It belongs to the `App` / `Org` / `Com` surfaces.
- It stores the current token-like preference state.
- It is used before login and after logout.
- It lives in `app_setting`, `org_setting`, or `com_setting`.

### Local preference

Local preference is the source of truth for account-local settings.

- It belongs to the `Client` / `Operator` / `Visitor` records.
- It stores per-account language, region, timezone, and theme settings.
- It is kept in each domain database.

## Synchronization Rules

The system uses explicit sync rules.

### Before login

- Write preference changes from the `sign` preference routes to `AppPreference`, `OrgPreference`, or
  `ComPreference`.
- Do not depend on local preference data.

### During login

- Write the same user-visible preference data to both shared preference and local preference.
- Keep the values aligned by explicit sync.
- If both sides already exist, reconcile by parent-record recency: the newer parent preference
  record wins as a whole record. This is intentional until the schema has per-field change metadata.

### During logout

- Write only to shared preference from the `sign` preference/logout boundary.
- Local preference remains as the account-local record.

### Sync failure handling

- Do not expose sync failure to the user as a product error.
- Keep the user-facing action successful when possible.
- Recover the state by writing back to the matching local preference when a shared/local sync fails.
- Emit a structured error log for later recovery and investigation.

Recovery target by surface:

- `App` -> `UserPreference`
- `Org` -> `OperatorPreference`
- `Com` -> `VisitorPreference`

Current implementation note: Com/Visitor adoption is implemented symmetrically with App/Client and
Org/Operator. `PreferenceAdoption#adoptable_preference_class?` treats `ComPreference` as adoptable,
and login-time and rotation-time sync create/update the `VisitorPreference` mirror the same way the
`UserPreference`/`StaffPreference` mirrors are created and updated.

Required log fields:

- `preference_type`
- `source`
- `target`
- `action`
- `error_class`
- `error_message`
- `owner_id`
- `surface` or `scope`
- `request_id` or another correlation key

## Data Sharing Rules

`App` / `Org` / `Com` preference data must not be treated as one shared row across all surfaces.

- Do not copy `App` data into `Org` or `Com`.
- Do not copy `Org` data into `App` or `Com`.
- Do not copy `Com` data into `App` or `Org`.

Each surface keeps its own preference state.

The local preference records also must stay isolated inside the matching principal bubble.

- `UserPreference` stays in the `app_principal` database.
- `OperatorPreference` stays in the `org_principal` database.
- `VisitorPreference` stays in the `com_principal` database.

## Shared Fields

The sync path should only move the allowlisted user-facing fields.

- `language`
- `region`
- `timezone`
- `theme`
- cookie consent fields when they are part of the active session state

## Promotional Email Unsubscribe

Promotional email opt-out is handled as a public, token-verified preference action on the sign
surfaces.

- The public path is `/preference/email/:id`, where `:id` is the email record `public_id`.
- The `token` query parameter is an HMAC generated from a dedicated
  `PROMOTIONAL_UNSUBSCRIBE_HMAC_SALT` secret.
- `app` uses the external HMAC scope `client` while it still updates the current `UserEmail`
  storage-backed model.
- `com` uses `VisitorEmail`; `org` uses `OperatorEmail`.
- `GET /preference/email/:id/edit` renders a confirmation page and does not change state.
- `DELETE /preference/email/:id` and Gmail one-click `POST /preference/email/:id` set `promotional`
  to `false` idempotently.

The sync path must not copy unrelated data.

- authentication secrets
- identity documents
- billing data
- moderation data
- message content
- operational audit payloads

## Request Context Parameters

The sign surfaces use the same request context contract for `app`, `org`, and `com`.

- `ri` carries the region.
- `lx` carries the language.
- `ct` carries the theme.
- `tz` carries the timezone.
- `cu`, `df`, `tf`, `mo`, `dn`, and `ps` carry optional display and locale-adjacent overlays.
- `pt` and `nt` carry redirect target lanes and are not propagated through ordinary preference
  navigation by default.

`ri` is mandatory request context. Current sign `app`, `org`, and `com` routes must carry a valid
`ri`. If `ri` is missing or invalid on a GET or HEAD request, the controller redirects to the same
route with a valid `ri` value. `ri` is request context, not a preference write path.

`lx`, `ct`, `tz`, `cu`, `df`, `tf`, `mo`, `dn`, and `ps` are optional request context. They are only
propagated when explicitly present and valid. The runtime preference subset may override the current
request's locale, theme, timezone, display reflection, or content-gating reflection by applying a
request-local overlay to `Actor.preferences`, but these parameters do not update the database or
preference access-token JWT. If they are missing, Rails request code should read the already
resolved value from `Actor.preferences`, without adding those optional keys back to generated URLs.
On GET and HEAD requests, invalid or blank optional context parameters are removed from the query
string by redirect.

Supported optional request values:

- `lx`: `ja`, `en`
- `ct`: `li`, `dr`, `sy`, or their long forms `light`, `dark`, `system`
- `tz`: `utc`, `etc/utc`, `asia/tokyo`
- `tf`: `12`, `24`, or their long forms `hour_12`, `hour_24`
- `mo`: `st`, `rd`, or their long forms `standard`, `reduced`
- `dn`: `st`, `cp`, or their long forms `standard`, `compact`
- `ps`: valid page size option values

## Public And Private URL Boundaries

Preference token validation is sensitive to the difference between a browser-visible host and an
internal Rails origin.

- `PUBLIC_` should be used for the host or URL the browser sees.
- `PRIVATE_` should be used for the host or URL Rails or a pod uses internally.

The preference access-token cookie path must keep these boundaries aligned. If Rails issues a token
for one boundary and immediately validates against the other, the browser can end up with a freshly
issued cookie that is then deleted on the same response.

Examples:

- `/preference?ri=jp&lx=en` uses English for that request.
- `/preference?ri=jp&lx=kr` redirects to `/preference?ri=jp`.
- `/preference?ri=jp&ct=purple&tz=Mars/Base` redirects to `/preference?ri=jp`.
- `/preference` redirects to the same route with a valid `ri`, but does not add `lx`, `ct`, or `tz`.

## Preference Reset

Preference reset is a fresh-visit rebootstrap, not an in-place defaults update. A successful reset
retires the current shared surface preference, clears preference auth and request-context cookies,
creates a new shared preference through the normal new-visitor bootstrap path, and redirects to the
same-surface `/preference` without request-context query parameters. The following GET then uses the
normal required-`ri` lifecycle to add the default region context.

## Runtime Read Contract

Preference data flows in one direction for Rails runtime reads:

```text
Preference JWT payload (`preference_access` / `__Host-preference_access`) -> Actor.preferences

The Preference JWT is an RFC 9068 `at+jwt` access token. Protocol claims (`iss`, `exp`, `aud`,
`sub`, `client_id`, `iat`, `jti`, `scope`) sit in the JWT Claims Set. Application preference data
remains in the private `preferences` object. `sub` is the preference record `public_id`. See
`adr/rfc9068-access-token-profile.md`.
```

The database is the durable storage boundary (SSoT) used by explicit preference write and
token-refresh flows. The **Preference JWT** (`*_preference_access` cookie) is its signed projection
and the Rails runtime read cache for normal requests. `Actor.preferences` is the immutable
request-local runtime preference value exposed to controllers, views, and services.

> **2026-05-30:** The hydration source changed from the auth access-token `prf` claim to the
> Preference JWT payload. The `prf` claim never mirrored the DB (it was built from the NULL+overlay
> value), so it was dead transport and is no longer read; its production is removed on the auth side
> in a separate task. The Preference JWT is decoded by `set_preferences_cookie`, which the
> controller lifecycle runs before `set_current_actor`, so hydration is a read-only, no-extra-DB
> step.

In a normal request, `Actor.preferences` is built in two stages:

1. Build the base preference from the Preference JWT payload (`preference_payload_preferences`), via
   `Actor::Preference.from_jwt`. When no Preference JWT cookie exists (Bearer/OIDC APIs and
   endpoints that skip `set_preferences_cookie`), fall back to the default preference values
   (theme `sy`). `Actor::Preference::NULL` is the unbound-context snapshot, not the guest default.
2. Overlay valid request-local `lx`, `ct`, and `tz` values when they were explicitly present in the
   request.

The overlay changes only the current request's runtime preference. It is not a preference write.

### Language resolution and dynamic region seeding

Child preference records are always created with a default option on first visit, so a saved value
cannot, by itself, distinguish an explicit user choice from an auto-seeded default. The
`explicit_fields` jsonb marker on `app/com/org_preferences` records which fields the user set on
purpose; it rides along in the payload as the `explicit` list. The effective language is resolved by
priority:

1. `?lx` request param (request-local; never written to DB/JWT).
2. An explicitly set language (present in `explicit_fields`) — wins over `?ri`.
3. `?ri`-derived dynamic seeding for users who have not set a language (`jp` -> ja, `us` -> en).
4. Default (`ja`).

Example:

```text
Preference JWT: lx=ja, ct=sy, tz=Asia/Tokyo
request params:   lx=en
Actor.preferences: language=en, theme=sy, timezone=Asia/Tokyo
```

The page renders in English for that request. The database and Preference JWT remain Japanese until
an explicit preference write path changes them and reissues a token.

### Region is a regional-bundle reset

A `/preference/region` write is not a single-field write. It rewrites the region-owned locale
defaults to the region's values in one transaction and marks each one explicit:

| Region | language | date format         | clock  | currency |
| ------ | -------- | ------------------- | ------ | -------- |
| `jp`   | `ja`     | `iso` (YYYY-MM-DD)  | 24h    | `jpy`    |
| `us`   | `en`     | `us` (MM/DD/YYYY)   | 12h    | `usd`    |

The individual language / calendar / clock / currency screens still let a person override any of
these afterwards; the override is then explicit and survives a later `?ri` change. If any of the
five child writes fails, the whole change rolls back — a half-applied bundle is never persisted.

Do not reverse this flow.

- Do not issue preference JWTs from `Actor.preferences`.
- Do not write the database from `Actor.preferences`.
- Do not read JS-readable preference cookies as Rails runtime input.
- Do not treat request context params as preference writes.
- Do not copy request-local `lx`, `ct`, or `tz` overlays back to the database or JWT.

`acme` and `jump` are runtime readers of this value. They must not persist preference settings, and
they must not treat request context, RP rendering, jump redirects, or read-side token consumption as
preference writes.

JS-readable preference cookies such as `language`, `ct`, and `tz` may be written by Rails for
compatibility with browser, Hono, edge, or UI code. Rails request code must not trust them as
preference input.

Database reads and writes are allowed only in bounded flows:

- new preference creation
- valid refresh-token rotation that intentionally reissues the preference JWT
- logged-in HTML preference edit entry refresh
- explicit `sign` preference update endpoints
- explicit `sign` preference reset or delete endpoints
- login-time adoption or sync
- repair, admin, or maintenance tasks

GET and HEAD writes are allowed only for the lifecycle exceptions recorded in
[`docs/security/db-write-allowlist.md`](../security/db-write-allowlist.md). Preference bootstrap,
refresh rotation, authenticated transparent refresh, throttled session activity touch, OIDC callback
handling, and logged-in preference edit entry refresh are separate categories and should not be
collapsed into a generic read-side repair path.

Normal authenticated request setup must not recover a missing, broken, or malformed preference
access-token by reading the preference database. Treat that as an authentication / token failure and
raise or fail the request through the normal error path. Database recovery belongs to a dedicated
refresh, write, repair, or administrative flow, not to generic `before_action` runtime setup.

Logged-in HTML preference edit screens are a bounded exception to the normal runtime path. Before
they initialize `Actor.preferences` and apply locale, timezone, or theme side effects, they may read
the actor-local preference database, copy that value into the current surface preference, and issue
a fresh preference access-token JWT. This keeps preference editing screens from showing stale values
when the same signed-in actor changed preferences in another browser or device. Request-local `lx`,
`ct`, and `tz` overlays are still applied only after this DB -> JWT refresh and are not copied back
to the database or JWT.

## Implementation Notes

- `Preference::ClassRegistry` decides which preference class is active.
- `Preference::Adoption` performs the login-time sync between shared and local preference.
- `Preference::Core` reads and updates the current preference snapshot.
- Surface preference records use the `app_setting`, `org_setting`, or `com_setting` database
  connection.
- `Actor::Preference` is the runtime read interface for request code. In the normal request path it
  is built from the Preference JWT payload, then valid request-local `lx`, `ct`, and `tz` values are
  overlaid when explicitly present. Request code reads the resolved effective value through
  `Actor.preferences`.
- Auth access tokens do not carry preference snapshots. Preference snapshots belong to the
  `*_preference_access` token payload, whose stable short keys include `lx`, `ri`, `tz`, and `ct`.
  Extended options use `cu` for currency, `df` for date format, `tf` for time format, `mo` for
  motion, `dn` for density, and `ps` for items per page.
- The obsolete auth access-token `prf` claim is no longer emitted. Existing already-issued tokens
  that contain it are ignored by runtime preference hydration until they expire.
- Region request context is mandatory. A valid `ri` request parameter wins for that request. If `ri`
  is missing, the system redirects to a valid `ri` value; optional context keys are not backfilled
  into URLs. `lx`, `ct`, and `tz` are optional; when valid and present they affect only the current
  request's `Actor.preferences` overlay.
- Region preference writes persist the saved region but do not rewrite the current request context.
  A `/preference/region` update must redirect with the incoming `ri` instead of deriving `ri` from
  the saved region value.
- Preference-changing HTML and JSON actions that update language, region, timezone, theme, currency,
  date format, time format, motion, density, items per page, cookie consent, or explicit resets must
  reload the shared preference record and reissue the preference access token before returning the
  response.
- Logged-in HTML preference edit screens must refresh the current surface preference token from the
  actor-local preference DB before `Actor.preferences` is initialized for the request. This is a
  screen-entry sync, not a generic fallback for broken JWTs.
- Preference access tokens carry a `jti` claim. Do not check the `jti` against the database in the
  normal Rails runtime read path; doing so turns the JWT into a database lookup ticket instead of a
  runtime cache. Database-backed `jti` checks belong only to refresh, write, repair, or other
  explicitly bounded flows.
- Extended option values are fixed reference-table rows with foreign keys for each shared/local
  preference prefix: `App`/`User`, `Org`/`Staff`, and `Com`/`Visitor`. The `User` and `Staff`
  prefixes are storage compatibility names for the current app and org local preference tables;
  runtime actors are `Client` and `Operator`.
- Core's `/api/v0/preferences/theme` and `/api/v0/preferences/cookie` JSON endpoints, and the
  remaining non-Core `/web/v0/theme` and `/web/v0/cookie` endpoints, provide the no-full-page-reload
  update path for dark mode and cookie consent. They update the matching preference record when a
  valid preference access token identifies it, then issue a fresh preference access token.
- Shared preference credential cookie names are scoped by surface (`app_preference_*`,
  `com_preference_*`, `org_preference_*`) only as legacy compatibility names. The current credential
  cookie names are role-based by credential type: `preference_access`, `preference_refresh`, and
  `preference_dbsc`, with the `__Host-` prefix in production. Legacy `__Secure-*` and scoped names
  may be read only for compatibility.

## Remaining Follow-ups

- Re-login reconciliation strategy is recorded in
  `adr/preference-relogin-reconciliation-record-recency.md`.
- Legacy duplicate model cleanup is tracked in
  `plans/backlog/legacy-preference-models-retirement-plan.md`; the obsolete `user_app_preferences`
  and `staff_org_preferences` bridges have been retired.
- Future database placement changes must be handled by their own migration plans; this document
  describes the current accepted layout.

## Open Questions

- Should shared preference keep a full history, or only the latest state?
- ~~Should logout clear the local copy, or only stop writing to it?~~ Resolved 2026-07-02:
  keep-values (do not clear or downgrade on logout). See
  `docs/architecture/preference-behavior-contract.md`'s State Transitions table and
  `memos/2026-07-02-preference-audit.md`.
- Should `App`, `Org`, and `Com` use the same shared schema forever, or should each surface keep a
  separate shape?
- Should activity records stay near the `com_setting` database, or move to a separate audit surface
  later?
- Should sync recovery always use the surface-matched local preference, or should the action type
  decide first?
