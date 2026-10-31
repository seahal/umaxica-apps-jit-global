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
- `ClientPreference` and `OperatorPreference` hold per-account local settings for app and org.
  Com has no account-local preference.

The system must keep these roles separate.

The database is the source of truth for both shared and local preference state. The Preference JWT
is a signed projection of that database state for runtime reads. Auth access tokens do not carry the
`prf` preference snapshot.

## JWT Projection Boundary

The active Preference transport is one realm-scoped signed value and two display cookies. App,
org, and com use the same anonymous token contract. Base owns save/reset; Visa App and Visa Org own
the sign-in/sign-out reflection. WU-9's persistence cutover still requires its separately approved
local shape migrations and final acceptance checks.

| Data         | JWT projection                 | Accepted target contract                                                                              |
| ------------ | ------------------------------ | --------------------------------------------------------------------------------------------- |
| Preference   | Preference JWT only            | App, org, and com use a realm-scoped `__Secure-preference`, `language`, and `__Secure-experience` cookie set. Auth access tokens do not carry `prf`. |
| Identity     | Auth/OIDC identity claims only | Credential, contact, verification, and lifecycle state remain DB-only.                        |
| Avatar       | None                           | Avatar selection and authority remain DB-only/session-row state.                              |
| Organization | None                           | Organization membership and role checks remain DB-only policy state.                          |
| Group        | None                           | Group membership and authorization remain DB-only policy state.                               |

OIDC ID token claims and auth access token claims are separate contracts. An ID token may describe
the authenticated subject for an RP. An auth access token may carry authentication/session facts for
the Rails authorization boundary. Neither token turns identity, avatar, organization, or group rows
into JWT-owned source-of-truth state.

Preference authority and preference transport are separate. Only the matching Base and Visa
surfaces write a realm's Preference database and hold that realm's signing key. Other hosts verify
the shared domain-scoped JWT and render read-only preference context. Base also owns the host-only
`__Host-preference_binding` cookie used to authorize consent and Web Push reads. A signed JWT by
itself is not consent authority. Other runtime code consumes display state as read-only context
through `Actor.preferences`.

## URL Role Boundary

Preference, setting, and operational configuration routes have separate responsibilities:

- `/preference` is the login-independent preference boundary. It may be used before login, after
  logout, or while authenticated. It owns shared surface preference state such as language, region,
  timezone, theme, display options, and cookie consent.
- `/setting` is the signed-in user setting boundary. It owns account-local and security settings for
  the current actor, such as credentials, sessions, MFA, contact methods, notification settings, and
  withdrawal flows.
- `/configurator` is the generic operator-controlled configuration boundary. It owns settings an
  authorized operator manages for an organization, workspace, tenant, public surface, or managed
  runtime.

The owner-approved WU-X1 migration gives the existing Base ORG management entry a surface-local
`/settings` route on the Base ORG host. Auth APP and ORG `/settings` remain their separate identity
self-service endpoints on the Auth hosts. These routes have independent controllers, sessions,
policies, and state; matching path text does not share an implementation. The Auth ORG
`/configuration` transfer endpoint was removed, and no `/configuration` alias or redirect remains.
The Base ORG entry remains closed until an authoritative settings data source exists. This is a
specific migration exception and does not establish `/settings` as the generic operator route.

Do not move preference writes under `/setting` merely because the actor is authenticated. Do not
expose account settings through `/preference` merely because a settings page also displays
preference context. Do not mix operator-managed configuration with user self-service settings.

These URL roles are canonical for new documentation and route work, subject to the explicit
Base-ORG-only migration above. Do not infer shared behavior from the repeated `/settings` path.

## Scope

### Shared preference

Shared preference is the source of truth for login-independent surface preference state.

- It belongs to the `App` / `Org` / `Com` surfaces.
- It stores the current token-like preference state.
- It is used before login and after logout.
- It lives in `app_setting`, `org_setting`, or `com_setting`.

### Local preference

Local preference is the source of truth for account-local settings.

- It belongs to `Client` or `Operator` records. Corporate (`com`) has no account-local preference.
- It stores per-account language, region, timezone, and theme settings.
- It is kept in each domain database.

## Synchronization Rules

The accepted target is one-way and field-explicit. The replacement
[sign-in application ADR](../../adr/preference-sign-in-application-is-one-directional.md) and
[realm JWT and binding ADR](../../adr/preference-realm-jwt-and-host-bound-browser-binding.md)
supersede the older record-recency and host-local transport contracts. App/org and com now use the
same realm JWT and Base host binding rules.

### Before login

- Anonymous preference writes target the matching `AppPreference`, `OrgPreference`, or
  `ComPreference` row.
- Account-local values are not written by anonymous save paths.

### During login

- After Visa has finalized sign-in, its shared Preference writer applies only account display values
  named in the account row's explicit metadata to the anonymous row. The anonymous row never writes
  back to the account. An account row with
  `explicit_fields IS NULL` has unknown historical provenance: it remains unchanged and supplies no
  inferred values.
- `region` is not applied by itself. A region save marks the fixed language, date format, time
  format, and currency companions explicit; those companions are the values applied on sign-in.
- Consent, Web Push, and browser binding remain browser-local. Sign-in does not import them from the
  account. Corporate preferences have no account adoption path.

### During logout

After authentication logout commits, Visa sign-out asks the shared Preference writer to create a
new anonymous generation, copy display values plus consent, Web Push option, and the binding record
from the old row's database state, and retire the old row in one setting transaction. It does not
infer Preference state from cookies. Account-local settings remain in place.

### Sync failure handling

The target writer follows the ordered Z-then-setting commits and explicit failure outcomes in
`two.md` §4.4 and §4.8. An account save that commits in Z but fails in the setting database is a
visible partial failure; it is not reported as saved. A sign-out remains complete when the
independent Preference rebuild fails, and the failure is reported without claiming that the new
Preference cookie reached the browser.

## Write Boundary

`PreferenceWriteBoundary#write_preference!` is the single accepted writer for `save`, `sign_in`,
`sign_out`, and `reset`. Base owns authenticated save/reset; Visa owns sign-in/sign-out. Each call
receives a server-verified actor and explicit submitted values. Request data cannot choose the actor,
realm, or operation. The surface-to-realm table is closed, and other hosts remain readers.

The same boundary serves Base com/app/org save/reset and Visa app/org sign-in/sign-out. A closed
surface-to-realm map refuses unregistered writers.

## Data Sharing Rules

`App`, `Org`, and `Com` preference data remain separate realm-local state.

- Do not copy `App` data into `Org` or `Com`.
- Do not copy `Org` data into `App` or `Com`.
- Do not copy `Com` data into `App` or `Org`.

Account-local preference records also remain isolated inside their matching principal boundary.
`ClientPreference` uses the app Zenith database; `OperatorPreference` uses the org Zenith database.
There is no corporate account-local preference.

## Shared Fields

The anonymous display snapshot supports these ten fields:

- `theme`
- `language`
- `timezone`
- `currency`
- `date_format`
- `time_format`
- `motion`
- `density`
- `page_size` (including the registered `infinity` value)
- `region`

`region` is stored in the database but is not a JWT display claim. A region save also marks its four
fixed display companions explicit. The shared cookie projection carries language and the experience
object with the other display values. Consent, Web Push option, and browser binding are stored in
separate browser-row children; they are not account-local fields. `adult_content_gate` remains a
dormant model/option/child family and is excluded from runtime display and save registries.

## Promotional Email Unsubscribe

Promotional email opt-out is handled as a public, token-verified preference action on the sign
surfaces.

- The public path is `/preference/email/:id`, where `:id` is the email record `public_id`.
- The `token` query parameter is an HMAC generated from a dedicated
  `PROMOTIONAL_UNSUBSCRIBE_HMAC_SALT` secret.
- `app` uses the external HMAC scope `client` while it still updates the current `UserEmail`
  storage-backed model.
- `org` uses `OperatorEmail`.
- The `com` visitor unsubscribe scope is retired: the corporate hosts no longer serve
  `/preference/emails` or any visitor contact surface, and `PromotionalEmailUnsubscribeHeaders`
  raises `ArgumentError` for the retired `visitor` option instead of falling back to another scope.
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

The app and org sign surfaces use the same request context contract. The anonymous corporate
(`com`) preference pages use the same `ri`/`lx`/`ct`/`tz` overlay without a principal.

- `ri` carries the region.
- `lx` carries the language.
- `ct` carries the theme.
- `tz` carries the timezone.
- `cu`, `df`, `tf`, `mo`, `dn`, and `ps` carry optional display and locale-adjacent overlays.
- `pt` and `nt` carry redirect target lanes and are not propagated through ordinary preference
  navigation by default.

`ri` is mandatory request context. Current sign `app` and `org` routes, and the anonymous `com`
preference pages, must carry a valid `ri`. If `ri` is missing or invalid on a GET or HEAD request, the controller redirects to the same
route with a valid `ri` value. `ri` is request context, not a preference write path.

Global browser HTML on Base, Auth, Visa, Tech and Edit MUST use this canonicalization contract.
Base Home/Dashboard and Visa public roots participate alongside ordinary browser pages. A missing
region uses the existing resolved context, defaulting to `jp`; explicit valid `jp` and `us` stay
selected. Valid query context survives the same-origin, same-path 302 redirect. Visa roots register
the shared callback explicitly while retaining their bare, cookie-free presentation boundary.
Protocol, JSON, metadata and health endpoints retain their existing transport exemptions. Core,
Palm, Warp and Publishing content retain their own context contracts. This supersedes the former
Base Home/Dashboard HTML in-place-only normalization and the Visa root exemption (2026-10-25).

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

The Preference JWT cookie path must keep these boundaries aligned. If Rails issues a token
for one boundary and immediately validates against the other, the browser can end up with a freshly
issued cookie that is then deleted on the same response.

Examples:

- `/preference?ri=jp&lx=en` uses English for that request.
- `/preference?ri=jp&lx=kr` redirects to `/preference?ri=jp`.
- `/preference?ri=jp&ct=purple&tz=Mars/Base` redirects to `/preference?ri=jp`.
- `/preference` redirects to the same route with a valid `ri`, but does not add `lx`, `ct`, or `tz`.

## Preference Reset

The accepted reset transition retires the currently valid anonymous row and creates a new row with
its registered defaults in the same setting-database transaction. After commit, the writer issues
the three shared Preference cookies from that new snapshot and deletes the old host-only browser
binding cookie. If the supplied JWT is invalid, the row it names stays unchanged; reset creates a
default row instead. The new contract does not return to the refresh/DBSC path.

The same transition uses the shared writer for com/app/org. It retires the current row, creates a
default replacement, issues the three shared cookies after commit, and clears the host-only binding
cookie.

## Runtime Read Contract

The read-only runtime projection is a domain-scoped Preference JWT. App/org and com hydrate through
the same realm claim shape:

```text
Preference JWT payload (`__Secure-preference`) -> Actor.preferences
```

The anonymous Preference JWT uses the closed realm shape defined by the accepted Preference ADRs.
Its `sub` identifies the anonymous preference row; `aud` identifies the realm. It is separate from
the RFC 9068 authentication access token.

The database is the durable storage boundary used by explicit Preference writes. The signed
Preference JWT is a runtime read cache. `Actor.preferences` is the immutable request-local
preference value exposed to controllers, views, and services. Preference JWT refresh-token and
DBSC flows are retired.

> **2026-05-30:** The hydration source changed from the auth access-token `prf` claim to the
> Preference JWT payload. The `prf` claim never mirrored the DB (it was built from the NULL+overlay
> value), so it was dead transport and is no longer read; its production is removed on the auth side
> in a separate task. The Preference JWT is decoded by `set_preferences_cookie`, which the
> controller lifecycle runs before `set_current_actor`, so hydration is a read-only, no-extra-DB
> step.

In a normal app/org request, `Actor.preferences` is built in two stages:

1. Build the base preference from the Preference JWT payload (`preference_payload_preferences`), via
   `Actor::Preference.from_jwt`. When no Preference JWT cookie exists (Bearer/OIDC APIs and
   endpoints that skip `set_preferences_cookie`), fall back to the default preference values (theme
   `sy`). `Actor::Preference::NULL` is the unbound-context snapshot, not the guest default.
2. Overlay valid request-local `lx`, `ct`, and `tz` values when they were explicitly present in the
   request.

The overlay changes only the current request's runtime preference. It is not a preference write.

### Anonymous corporate requests

The corporate (`com`) hosts have no principal, credential, session, or admission boundary, so their
hydration is a separate path:

1. `ComAnonymousActorContext#set_anonymous_context` installs one request-local actor snapshot with
   `Unauthenticated`, `Actor::Authentication::NULL`, `Actor::Authz::NULL`,
   `Actor::Configuration::NULL`, and `Actor::SelectedContext::NULL`.
2. The initial preference starts from `Actor::Preference.new` and the request overlay. After token
   verification, a valid com JWT supplies the display values and the request overlay is applied to
   the request-local snapshot. With no valid JWT, the initial default and overlay remain in use.
3. `prepend_around_action :with_anonymous_context_lifecycle` clears the actor snapshot and restores
   the thread's time zone when the request ends.

`Base::Com::ApplicationController` and `Warp::Com::ApplicationController` include the concern
explicitly and do not include the principal-resolving authentication or adoption concerns. Warp com
verifies the JWT without reading the setting database. Base com can read the preference row for its
settings and browser-bound consent and Web Push endpoints. Consent and Web Push remain endpoint
responses; Base does not copy their database values into the request-local Actor preference. The
actor snapshot carries only the verified display projection and request overlay. Other com hosts
retain the disabled Web Push default.
Base also reads the region of an active, unexpired anonymous preference without requiring a browser
binding; an explicit URL region overlays that value for the request. The independent com signing
namespace and lifecycle schema are present locally; deployment key distribution and full WU-7
acceptance remain unverified.

### Language resolution and regional defaults

The anonymous JWT stores language as a display value and has no explicitness marker. Request
context is applied locally in this order:

1. `?lx` request param (request-local; never written to DB/JWT).
2. `?ri` regional locale (`jp` -> ja, `us` -> en).
3. Language from the verified Preference JWT.
4. Default (`ja`).

Example:

```text
Preference JWT: lx=ja, ct=sy, tz=Asia/Tokyo
request params:   lx=en
Actor.preferences: language=en, theme=sy, timezone=Asia/Tokyo
```

The page renders in English for that request. The database and Preference JWT remain Japanese until
an explicit preference write changes them and reissues a token.

### Region is a regional-bundle reset

A `/preference/region` write is not a single-field write. It rewrites the region-owned locale
defaults to the region's values in one transaction. For a signed-in actor, it marks the region and
its four companion values explicit in the actor-local preference metadata:

| Region | language | date format        | clock | currency |
| ------ | -------- | ------------------ | ----- | -------- |
| `jp`   | `ja`     | `iso` (YYYY-MM-DD) | 24h   | `jpy`    |
| `us`   | `en`     | `us` (MM/DD/YYYY)  | 12h   | `usd`    |

The individual language / calendar / clock / currency screens still let a person override any of
these afterwards. A later request-region overlay affects only that request. If any of the five
child writes fails, the whole preference update reports failure rather than claiming the bundle was
saved.

Do not reverse this flow.

- Do not issue preference JWTs from `Actor.preferences`.
- Do not write the database from `Actor.preferences`.
- Do not read JS-readable preference cookies as Rails runtime input.
- Do not treat request context params as preference writes.
- Do not copy request-local `lx`, `ct`, or `tz` overlays back to the database or JWT.

`acme` and `jump` are runtime readers of this value. They must not persist preference settings, and
they must not treat request context, RP rendering, jump redirects, or read-side token consumption as
preference writes.

The current readable display cookies are `language` and `__Secure-experience`. Rails derives both
from the same verified database snapshot as the Preference JWT. Per-item cookies such as `ct` and
`tz` are retired; Rails request code does not trust readable display cookies as preference input.

Database writes are allowed only in bounded flows:

- explicit Base Preference save and reset
- Visa sign-in application after the authenticated transaction is finalized
- Visa sign-out rebuilding after authentication logout commits
- no other host, endpoint, or maintenance path writes Preference state

GET and HEAD do not create, update, or refresh Preference rows. Preference reads are limited to
verified JWT state and bounded database reads such as Base consent/binding checks.

Normal request setup must not recover a missing, broken, or malformed Preference JWT by reading the
Preference database. Writes start a default row when the supplied JWT does not identify a current
row; GET/HEAD do not issue a replacement token.

Authenticated preference screens resolve the verified anonymous JWT and actor context like other
Base requests. A screen read never copies actor values into the anonymous row. An explicit save
updates only submitted actor fields and the browser snapshot.

## Implementation Notes

- `PreferenceClassRegistry` names the registered realm and account classes. New code uses the
  registry's static class maps and fails on an unknown prefix.
- `PreferenceWriteBoundary#write_preference!` is the shared write entrance for `save`, `sign_in`,
  `sign_out`, and `reset`. Its closed surface map names Base and Visa writers.
- `ActorPreferenceExplicitDisplay#explicit_display_snapshot` reads only explicitly named display
  children. An old actor row whose `explicit_fields` is `NULL` remains historical and read-only; it
  cannot supply a snapshot, and child values do not establish explicit intent. The approved shape
  requires this field to be NOT NULL. `region` and dormant `adult_content_gate` are not transferred
  by Visa sign-in.
- App/org setting databases have consent receipt, browser binding, and Web Push option child tables.
  Visa sign-out copies those records only from the source row in the matching setting transaction.
- App/org Preference adoption, refresh, DBSC, assurance, and item-cookie paths are retired.
- The accepted anonymous JWT projection is the closed display snapshot, with `language` and
  `__Secure-experience` generated from one database snapshot. The registered page-size value
  `infinity` remains valid. Unknown option names and keys fail instead of acquiring aliases.
- `adult_content_gate` models, options, and child tables remain dormant. Its controller/runtime
  registry references have been removed while the model-layer tables remain.
- Runtime readers consume verified preference context through `Actor.preferences`. Request-local
  region/language/theme/timezone overlays do not become writes.
- The accepted ADRs are indexed in `adr/README.md`. The older record-recency and host-local
  transport ADRs are historical and must not be reinstated as the current contract.

## Remaining Follow-ups

- Apply the WU-9 database shape only after the current §12.8 execution ticket and local cutover
  approval are confirmed. The destructive local migrations have not been run.
- Complete WU-9 public acceptance coverage and one full-suite comparison after the approved local
  shape cutover.
- Complete WU-7 acceptance separately. Its implementation and local schema do not by themselves
  establish the full-suite acceptance result.

## Open Questions

No preference transport, sign-in direction, Web Push representation, legacy JWT compatibility, or
old account `explicit_fields IS NULL` classification question remains open. The owner-approved
answers are recorded in `plans/2026-10-28-wu-p0-preference-adr-revisions.md` and
`evidence/2026-10-31-wu9-p0-owner-decisions-V6J3.md`.
