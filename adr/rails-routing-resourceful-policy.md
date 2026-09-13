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

Boundary wrappers are allowed:

- `namespace`
- `scope module: ...`
- `scope(module: ..., as: ...)`
- `constraints(host: ...)`
- `constraints(subdomain: ...)`

These wrappers define module, helper, host, realm, or surface boundaries. They do not permit
non-resourceful routes inside them.

The following require explicit approval and ADR history before use:

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

The following exception classes are allowed when used only for their stated purpose:

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

Host constraints and module/helper scopes are allowed as boundary declarations:

```ruby
constraints(host: allowed_hosts) do
  scope(module: :app, as: :app) do
    resources :accounts, only: %i[index show]
  end
end
```

## Exception process

When a route cannot be represented with `resource` or `resources`, implementation must stop.

The implementer must ask for approval before adding the route.

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

| Date       | Route file                                                                                                                  | Route / snippet                                                                                                                                 | Exception type                               | Reason                                                                                                                                                                                | Approved by   | Lifetime                                 | Tests                                        |
| ---------- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ---------------------------------------- | -------------------------------------------- |
| 2026-07-05 | `config/routes/base.rb`                                                                                                     | `resource :csp_violation_report, only: :create, path: "csp-violation-report"`                                                                   | `path:`                                      | CSP/security reporting ingress endpoint                                                                                                                                               | project owner | permanent                                | route/request spec                           |
| 2026-07-05 | `config/routes/base.rb`, `config/routes/auth.rb`, `config/routes/core.rb`, `config/routes/side.rb`, `config/routes/palm.rb` | `root ...`, `.well-known/*`, `robots.txt`, `sitemap.xml`, OAuth/OIDC callbacks, OmniAuth callbacks                                              | pre-approved protocol / infrastructure route | Browser, protocol, and health contracts need stable public paths                                                                                                                      | project owner | permanent                                | route recognition and request specs          |
| 2026-07-05 | `config/routes/auth.rb`, `config/routes/base.rb`, `config/routes/side.rb`, `config/routes/core.rb`, `config/routes/palm.rb` | `namespace :sign { resource :termination, path: "out", controller: :outs, as: :out { resource :completion, path: "complete", module: :outs } }` | `path:`, `controller:`, `as:`                | Preserve current `/sign/out` ceremony URL and helper contract while keeping controllers under the `Sign::Outs` namespace                                                              | project owner | permanent until a later ADR removes them | route contract specs                         |
| 2026-07-14 | `config/routes/side.rb`, `config/routes/core.rb`, `config/routes/palm.rb`                                                   | (resolved) `resource :authorization, only: :show, to: "/core/app/auth/authorizations#show"` and equivalents                                     | `to:` controller override — **eliminated**   | Controllers relocated from `<realm>/<surface>/auth/` (and palm's `oauth/`) into `<realm>/<surface>/oidc/` so `namespace :oidc` resolves them by convention; no `to:` override remains | project owner | n/a (resolved)                           | route recognition and controller integration |

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
