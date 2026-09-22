# Content-surface OIDC registration retirement audit

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD observed: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing changes were present and preserved; no reset, clean, commit, GitHub
  write, external service access, or external configuration change was performed.
- Frozen Plan requirement: `FREQ-0016`

## Scope

This audit evaluates whether the repository can safely retire the Rails OIDC registrations for
`docs`, `news`, and `help`. It does not remove registrations, keys, tests, or documentation.
The Frozen Plan requires proof that no current required caller depends on those registrations
before retirement. `info` has no content RP registration in the inspected registry and no new
registration was proposed.

## Repository evidence

The static registry still defines nine content RP entries in
`app/values/oidc_client_stores_static_client_store.rb:230-276`:

- `docs_app`, `docs_com`, `docs_org`
- `news_app`, `news_com`, `news_org`
- `help_app`, `help_com`, `help_org`

The registry maps these entries to `umaxica-docs-*`, `umaxica-news-*`, and `umaxica-help-*`
audiences and to surface-specific URL environment keys. They are therefore real registry
entries, not comments or dead constants that can be removed without a contract decision.

The inspected route files (`config/routes/docs.rb`, `config/routes/news.rb`,
`config/routes/help.rb`, and `config/routes/info.rb`) expose public content roots and read-only
content APIs. They do not define ordinary OIDC authorization, callback, token, userinfo, or JWKS
routes for these content surfaces. `test/integration/content_surface_boundary_test.rb` also
asserts that docs, help, and news do not expose RP or provider endpoints and that their content
API rejects mutation verbs.

The current architecture documentation describes Edge as the public frontend and Rails as the
thin content/read-API boundary. `docs/architecture/docs-help-news-content-boundary.md:14-18,46-61`
and `adr/read-only-content-surfaces-in-rails.md:21-25,122-127` describe the content surfaces as
not owning Rails authentication or OIDC lifecycle. The latter ADR explicitly treats the existing
registry entries as a separate integration question rather than authoritative proof that they
are still required.

The exact content client identifiers and registry keys were found in the static registry and in
OIDC-focused tests, but no exact content client identifier was found in production callers under
`app/`, `config/`, or `lib/` outside that registry. Tests still exercise content client records,
including `test/services/oidc/client_registry_test.rb`,
`test/services/oidc/token_exchange_service_test.rb`,
`test/services/oidc_token_revoker_surface_lookup_test.rb`, and
`test/models/concerns/oidc_connection_record_test.rb`. Those tests demonstrate repository-level
assumptions and would require an intentional contract update if retirement is approved; they do
not prove that no external caller exists.

## Adversarial assessment

Two independent risks remain:

1. Retaining the entries leaves stale registration and credential-surface risk if the registry is
   later treated as an active authorization boundary without an owner.
2. Removing them now can break an external caller or an external registration that is not visible
   in this repository. The registry includes redirect and audience configuration, so deletion is
   an externally observable contract change rather than a local cleanup.

The available repository evidence is sufficient to show that the current Rails route boundary is
read-only and does not implement content OIDC endpoints. It is not sufficient to prove that the
registrations have no external required callers. No external registration, key-management system,
Cloudflare configuration, or provider was contacted, as required by the task boundary.

## Disposition

`FREQ-0016`: `BLOCKED_BY_DEPENDENCY` / `NEXT_CYCLE` for retirement implementation.

No registry entry, key, route, test, or production behavior was removed. This is not a plan-wide
critical blocker because the content route boundary is already read-only and independent work can
continue. It is a release-relevant dependency for the specific retirement requirement.

Before implementation, obtain an approved caller inventory and retirement window covering:

- external authorization-code and token callers, if any;
- registered redirect, logout, and key-credential state;
- migration or revocation treatment for any existing content RP sessions;
- replacement ownership if a content surface still requires access restriction.

After that evidence is approved, update the registry and its tests together, remove only obsolete
documentation, and verify that `info` still has no invented registration. Do not infer completion
from the absence of local production call sites alone.

## Verification record

Commands used:

- `git rev-parse HEAD`
- `git status --short --branch`
- `nl -ba app/values/oidc_client_stores_static_client_store.rb | sed -n '1,110p;220,300p'`
- `nl -ba docs/architecture/docs-help-news-content-boundary.md | sed -n '1,150p'`
- `nl -ba adr/read-only-content-surfaces-in-rails.md | sed -n '1,145p'`
- repository-scoped `rg` searches for content RP identifiers and OIDC routes
- `sed -n '1,220p' test/integration/content_surface_boundary_test.rb`

No Rails or JavaScript test was run in this shell for this read-only audit. Existing repository
test evidence remains historical evidence and is not reclassified as a current run. No application
code, test, migration, configuration, or external service was changed.
