# The OpenAPI Bundle Lives Outside public/

Accepted: 2026-09-17

## Context

`openapi/` is the source tree for the three per-surface API descriptions; Redocly bundles it into
single files that Committee validates against, that `bun run openapi:verify` checks for freshness,
and that any future client generator would read. Those bundles were written to
`public/openapi.{app,com,org}.yml`.

`public/` is served statically in development — `config/environments/development.rb` sets
`config.public_file_server.enabled = true`. So the complete internal description of every JSON
endpoint, its parameters, and its response shapes was readable, with no credential, from every host
Host Authorization admits.

Production was never affected: `config/environments/production.rb` sets
`config.public_file_server.enabled = false`, and `config/initializers/content_security_policy.rb`
already relies on that being so.

Introducing Swagger UI on `swagger.umaxica.dev` forced the question. That surface exists to serve
these descriptions to a person, behind a credential. Leaving an unauthenticated copy on a path every
other development host also answers would have made the authentication decorative.

## Decision

The bundles move to `openapi/bundled/openapi.{app,com,org}.yml`, beside the source tree they are
generated from and outside `public/`.

This is not un-publishing something that was meant to be public. `redocly.yaml` already recorded the
intent, in the rationale for disabling its `info-license` rule: *"This is a first-party internal API
description, not a published artifact. The repository is private and ships no licence."* `public/`
was where the build artifact happened to land, not a publishing decision. No intentionally public
API specification was made private by this change.

One directory stays the single source of truth for every consumer:

| Consumer | How it reads them |
| --- | --- |
| Committee / Minitest | `OpenapiContract.schema_path`, the one resolver in the suite |
| Redocly | `output:` in `redocly.yaml` |
| CI | `openapi:verify` in `package.json` |
| Swagger UI | `rswag-api`, with `openapi_root` set to the same directory, behind the swagger host's Basic Auth |

No Swagger-specific copy is made. `OpenapiContract::BUNDLE_DIRECTORY` is the constant the others
refer to.

Files updated with the move: `redocly.yaml`, `package.json`, `.oxfmtrc.json`, `lefthook.yml`,
`openapi/shared/components.yml`, and `test/support/openapi_contract.rb`. The files were moved with
`git mv` so history follows.

Historical records under `adr/`, `evidence/`, `notes/`, and `plans/analysis/` still say
`public/openapi*.yml`. They describe what was true when they were written and were left alone.

## Consequences

- The descriptions are no longer fetchable without a credential from any development host. The only
  HTTP path to them is `https://swagger.umaxica.dev/openapi/openapi.<surface>.yml`, behind
  `SWAGGER_USERNAME` / `SWAGGER_PASSWORD`.
- Anything outside this repository that fetched `/openapi.app.yml` from a development host breaks,
  and should be pointed at the swagger host or read the file off disk.
- Per `adr/no-test-suite-for-environment-construction.md`, no test asserts that `public/` stays
  clear of OpenAPI documents. If a future `redocly.yaml` edit points an `output:` back at `public/`,
  nothing fails automatically. `redocly.yaml`'s header comment states why the bundle must stay out
  of `public/`; that comment is the guard.

## Related

- `adr/diagnostic-surfaces-performance-coverband-swagger.md` — the Swagger surface that reads these
- `adr/api-versioning-and-client-conventions.md` — why the descriptions are split per surface
- `adr/no-test-suite-for-environment-construction.md`
