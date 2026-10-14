# ADR: Rails routing must be resourceful by default

## Status

Accepted (2026-07-05)

## Context

The application has multiple Rails route surfaces and host-bound realms. Historically, routes have
used a mixture of `resource`, `resources`, custom verb routes, `path:`, `controller:`, `to:`, `as:`,
`defaults:`, host constraints, protocol endpoints, and compatibility shims.

That made it easy for business operations to leak into route and controller action names and for
route vocabulary, controller vocabulary, path vocabulary, and helper vocabulary to diverge.

We want Rails routing to remain predictable, conventional, and easy to review.

## Decision

Application routes must be expressed with `resource` or `resources` by default.

Normal controller actions should stay within:

- `index`
- `show`
- `new`
- `edit`
- `create`
- `update`
- `destroy`

Business verbs must be modeled as noun resources instead of custom route actions.

### Route classification

Classify every route as A, B or C:

- **A — normally allowed:** `resource` / `resources` using only the seven standard actions above.
  `namespace`, `scope` and host constraint wrappers may establish module, helper, path or host
  boundaries; they do not authorize non-resourceful routes inside the wrapper.
- **B — approved exception:** an exception already approved and recorded in this ADR, or one
  explicitly approved by the user and recorded here before implementation. The record names its
  purpose and exact extent (route file, host, path, method, controller/action and helper), reason,
  approval source and reference. Existing protocol and infrastructure classes below remain limited
  to their stated purpose; the category list is not blanket approval for new business routes.
- **C — normally prohibited:** anything outside A or B, including unapproved business-specific
  actions, custom `member` / `collection`, unapproved `match`, routes built from request or database
  input, and route-level overrides without a matching approval. Existing C routes are debt and are
  not silently changed.

Using `get` or `post` alone does not make a route B. Route-level `path:`, `controller:`, `to:`,
`as:` and `defaults:` remain restricted. These are distinct from permitted boundary wrappers.

Boundary wrappers are allowed:

- `namespace`
- `scope` wrappers used only to establish module, helper or path boundaries
- `constraints(host: ...)`
- `constraints(subdomain: ...)`

These wrappers define module, helper, host, realm, or surface boundaries. They do not permit
non-resourceful routes inside them.

The following require an applicable B approval and ADR history before use:

- `get`
- `post`
- `patch`
- `put`
- `delete`
- `match`
- `mount`
- `redirect`
- route-level `to:`
- route-level `controller:`
- route-level `path:`
- route-level `as:`
- route-level `defaults:`
- custom `member`
- custom `collection`

## Pre-approved exceptions

The following existing exception classes are allowed only for their stated protocol or
infrastructure purpose and recorded extent. They do not approve arbitrary routes that use the same
DSL method:

- `root`
- health check endpoints
- `/up`
- `/robots.txt`
- `/sitemap.xml`
- `/csp-violation-report`
- `.well-known/openid-configuration`
- `.well-known/jwks.json`
- OAuth/OIDC protocol endpoints
- OmniAuth callback endpoints
- externally specified callback endpoints
- webhook endpoints
- security report endpoints
- Rails engine mounts
- Rack app mounts
- framework-generated routes
- redirect-only legacy compatibility routes

`root` routes and mounts that answer at `/` share a maximum of one root definition per concrete
FQDN. Count each route definition once across all route files, expand every concrete host alias, and
include overlapping or unconstrained definitions. Route order determines which route handles a
request but does not erase a duplicate; record its effect and priority without fixing it unless the
change is separately authorized.

Existing routing DSL `param:` options are debt unless this ADR contains an individual route approval
for them. Do not add new `param:` uses. Ordinary resources retain Rails' default `:id` parameter;
public identifier lookup remains in the established model/controller contract.

Host constraints and module/helper scopes are allowed as boundary declarations:

```ruby
constraints(host: allowed_hosts) do
  scope(module: :app, as: :app) do
    resources :accounts, only: %i[index show]
  end
end
```

## Exception process

When a route cannot be represented with `resource` or `resources`, implementation must stop unless
an applicable B exception already exists.

For a new exception, the implementer must ask for approval before adding the route.

The approval request must include:

1. proposed route
2. route file
3. reason resourceful routing is insufficient
4. external protocol or compatibility requirement
5. controller/action
6. helper/path
7. expected lifetime
8. tests to add
9. proposed ADR update

After approval, the exception must be recorded in this ADR or in a follow-up ADR linked from this
one.

## Exception ledger

Record approved exceptions here.

| Date       | Route file                                                                                                                                 | Route / snippet                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Exception type                                                | Reason                                                                                                                                                                                                                                                                                                                                                            | Approved by                                             | Lifetime                                             | Tests                                                                                                                                  |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-07-05 | `config/routes/base.rb`                                                                                                                    | `resource :csp_violation_report, only: :create, path: "csp-violation-report"`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | `path:`                                                       | CSP/security reporting ingress endpoint                                                                                                                                                                                                                                                                                                                           | project owner                                           | permanent                                            | route/request spec                                                                                                                     |
| 2026-07-05 | `config/routes/base.rb`, `config/routes/auth.rb`, `config/routes/core.rb`, `config/routes/side.rb`, `config/routes/palm.rb`                | `root ...`, `.well-known/*`, `robots.txt`, `sitemap.xml`, OAuth/OIDC callbacks, OmniAuth callbacks                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | pre-approved protocol / infrastructure route                  | Browser, protocol, and health contracts need stable public paths                                                                                                                                                                                                                                                                                                  | project owner                                           | permanent                                            | route recognition and request specs                                                                                                    |
| 2026-07-05 | `config/routes/auth.rb`, `config/routes/base.rb`, `config/routes/side.rb`, `config/routes/core.rb`, `config/routes/palm.rb`                | `namespace :sign { resource :termination, path: "out", controller: :outs, as: :out { resource :completion, path: "complete", module: :outs } }`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `path:`, `controller:`, `as:`                                 | Preserve current `/sign/out` ceremony URL and helper contract while keeping controllers under the `Sign::Outs` namespace                                                                                                                                                                                                                                          | project owner                                           | permanent until a later ADR removes them             | route contract specs                                                                                                                   |
| 2026-07-14 | `config/routes/side.rb`, `config/routes/core.rb`, `config/routes/palm.rb`                                                                  | (resolved) `resource :authorization, only: :show, to: "/core/app/auth/authorizations#show"` and equivalents                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `to:` controller override — **eliminated**                    | Controllers relocated from `<realm>/<surface>/auth/` (and palm's `oauth/`) into `<realm>/<surface>/oidc/` so `namespace :oidc` resolves them by convention; no `to:` override remains                                                                                                                                                                             | project owner                                           | n/a (resolved)                                       | route recognition and controller integration                                                                                           |
| 2026-10-13 | `config/routes/core.rb` (app/com/org), `config/routes/warp.rb` (app/com/org), `config/routes/edit.rb` (org), `config/routes/palm.rb` (app) | `GET /sign` → `sign/entries#show`; `POST /sign` → `sign/entries#create`.<br>Hosts: `jp.umaxica.app`, `jp.umaxica.com`, `jp.umaxica.org`, `core.app.localhost`, `core.com.localhost`, `core.org.localhost`, `www-jp.umaxica.app`, `www-jp.umaxica.com`, `www-jp.umaxica.org`, `warp.app.localhost`, `warp.com.localhost`, `warp.org.localhost`, `edit.umaxica.org`, `edit.org.localhost`, `palm-jp.umaxica.app`, `palm.app.localhost`.<br>Helpers: `core_app_sign_show_path`, `core_app_sign_create_path`, `core_com_sign_show_path`, `core_com_sign_create_path`, `core_org_sign_show_path`, `core_org_sign_create_path`, `warp_app_sign_show_path`, `warp_app_sign_create_path`, `warp_com_sign_show_path`, `warp_com_sign_create_path`, `warp_org_sign_show_path`, `warp_org_sign_create_path`, `edit_org_sign_show_path`, `edit_org_sign_create_path`, `palm_app_sign_show_path`, `palm_app_sign_create_path`. | `get`, `post`, route-level `to:` / `as:`                      | The neutral RP entry contract keeps one stable `/sign` path: GET displays without starting a flow; CSRF-protected POST starts it. A singular resource changes that contract. See `adr/sign-neutral-entry-and-logout-target-authorization.md`.                                                                                                                     | user, 2026-10-13, GO for frozen plan REQ-074            | permanent while the neutral-entry contract stands    | Existing neutral RP entry and route contract tests; no test added in this documentation-only step                                      |
| 2026-10-13 | `config/routes/palm.rb`, `config/routes/tech.rb`                                                                                           | `resource :out_completion, only: %i(show create), path: "out/completion", controller: "out/completions"`; GET/POST `/sign/out/completion`; helpers `palm_app_sign_out_completion_path`, `tech_org_sign_out_completion_path`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `path:` and `controller:` resource aliases                   | First-party RP sign-out uses the approved noun completion route. GET displays the continuation or completion without consuming the transaction; POST advances the protected continuation. See `adr/first-party-sign-out-shared-database-without-backchannel-logout.md` and REQ-006 / DEC-088 in `one.md`.                                                                                                                               | user, GO for frozen plan REQ-006 / DEC-088              | permanent while the shared completion contract stands | Palm and Tech route contract tests; shared sign-out completion behavior remains in the S3/S4 verification scope                                                                                                                                 |
| 2026-10-13 | `config/routes/core.rb`, `config/routes/warp.rb`, `config/routes/edit.rb`, `config/routes/base.rb`                                           | `resource :out_completion, only: %i(show create), path: "out/completion"`; GET/POST `/sign/out/completion`; helpers `core_{app,com,org}_sign_out_completion_path`, `warp_{app,com,org}_sign_out_completion_path`, `edit_org_sign_out_completion_path`, `base_{app,com,org}_sign_out_completion_path`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | resource `path:` and controller options                        | All remaining first-party Browser RPs use the same noun completion route. GET is read-only; POST advances the protected continuation through the existing surface-local sign-out controller. The exact completion URI is registered before it is emitted. See `adr/first-party-sign-out-shared-database-without-backchannel-logout.md`, REQ-006 / DEC-088 in `one.md`.                                                      | user, request to implement frozen `one.md` REQ-006    | permanent while the shared completion contract stands | Route recognition, exact registered URI matrix, read-only GET and protected POST continuation tests                                                                                                                                              |
| 2026-10-13 | `config/routes/tech.rb`                                                                                                                    | `root to: "roots#index"`; `scope path: "sign", as: :sign { get "", to: "sign/entries#show", as: :show; post "", to: "sign/entries#create", as: :create }`; helpers `tech_org_root_path`, `tech_org_sign_show_path`, `tech_org_sign_create_path`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | `root` (pre-approved class); verb routes with `to:` and `as:` | Tech is the global operator Browser RP on the configured `tech_staff` host. Its root is a thin landing page. The neutral-entry contract keeps GET passive and requires CSRF-protected POST to start the OIDC flow; a singular resource changes the shared `/sign` path. See `adr/sign-neutral-entry-and-logout-target-authorization.md`.                                                                                                                              | user, GO for frozen plan REQ-047 / DEC-059             | permanent while the neutral-entry contract stands    | Tech route contract; GET/HEAD passive tests; missing, invalid, same-origin missing-token and mismatched-origin POST tests                                                                                                                                 |

Ledger notes (2026-10-13): the Tech neutral-entry row records its implemented route and host
contract. The preceding neutral `/sign` row remains scoped to Core, Warp, Edit and Palm. The two
completion-route rows together cover every first-party Browser RP surface without changing the
existing `/sign/out` start route.

## Consequences

Positive:

- routes become easier to audit
- controller action vocabulary stays small
- business verbs are modeled as resources
- path/helper/controller naming drift is reduced
- host and surface boundaries remain explicit
- exceptions become visible and reviewable

Negative:

- more controllers may be created
- some existing helpers and paths may change
- protocol and compatibility endpoints need explicit exception records
- contributors must ask before adding non-resourceful routes

## Enforcement

The coding harness must instruct agents to avoid non-resourceful routing. Agents must not add
routing exceptions without user approval. Tests must be added before route changes. ADR history must
be updated for every approved exception.
