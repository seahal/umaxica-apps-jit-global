# Rails Core BFF boundary audit

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD observed: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Frozen Plan requirements: `FREQ-0021`, `FREQ-0050`, `FREQ-0051`
- Worktree: pre-existing changes and the Palm slice were preserved; no external service or GitHub
  write was performed.

## Current boundary

The inspected `config/routes/core.rb` defines Core app/com/org roots, the versioned API, the
canonical session probe, OIDC callback/backchannel routes, token refresh, preferences, revision,
and health endpoints. It does not define a Rails `/dashboard` page route. The existing route
contract test asserts that `/dashboard` is unroutable on all three Core hosts.

`CoreBrowserApiBoundary` is included by the three Core API base controllers. Its current behavior
is consistent with the frozen boundary:

- `Cache-Control: no-store` is installed at the boundary;
- browser authentication is read from the RP access cookie;
- a presented `Authorization` bearer credential is rejected rather than accepted as fallback;
- invalid, missing, inactive, or wrong-resource credentials fail closed;
- unsafe methods require the Rails CSRF header while GET/HEAD/OPTIONS remain readable;
- errors use the existing Problem Details renderer;
- authenticated actor context is installed with Core surface and cookie/browser transport facts;
- the session probe returns anonymous `200` with `authenticated: false`, or authenticated actor
  data using `public_id`, not the database primary key.

The three session controllers are separate surface implementations and use the shared boundary;
no shared Core-to-Side fetch or Side credential fallback was found in `app/controllers/core/`,
`app/services/`, `app/values/`, or `config/routes/core.rb`. `rg` matches for `side` in this scope
were registry/config vocabulary or comments, not a Core data dependency.

The existing zero-cookie edge contract and the accepted Core cookie-boundary ADR continue to mark
TanStack SSR authentication as a separate follow-up decision. No bearer workaround, cookie-format
handoff, localStorage credential, CORS relaxation, or Rails dashboard was added.

## Disposition

`FREQ-0021`, `FREQ-0050`, and `FREQ-0051`: `ALREADY_SATISFIED` by repository evidence, subject to
runtime revalidation in the core service. No production code change was necessary in this slice.

The Frozen Plan names `docs/architecture/core-bff-boundary.md` as a possible documentation
destination, but that file does not exist. The current authoritative material is split between
`adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`,
`docs/operations/core-nextjs-zero-cookie-edge-contract.md`, and the Core route/API contracts.
No duplicate architecture document was created solely to satisfy a stale path reference.

## Verification record

Commands used:

- `rg` over Core controllers, services, values, and routes for Side dependencies;
- `nl -ba config/routes/core.rb`;
- `nl -ba app/controllers/concerns/core_browser_api_boundary.rb`;
- `nl -ba app/controllers/core/*/api/v0/sessions_controller.rb`;
- `rg` over Core boundary and route contract tests;
- `find docs/architecture` and `rg` over the zero-cookie ADR/operations contract.

The current shell could not execute Rails tests because `primary` and `valkey-kvs` are not resolvable
outside the Compose core service. Existing repository test evidence is not reclassified as a new
run. No environment value was replaced and no setup or production code was changed.
