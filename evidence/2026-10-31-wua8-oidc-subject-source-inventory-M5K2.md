# Base canonical subject source inventory

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including subject and RP authentication code; the observations apply to that worktree.

`OidcSubject.for` uses an `oidc_subject` method when available and populated, otherwise a `public_id`, and prefixes it with `cli_` or `opr_`. A source search found no explicit `oidc_subject` method or attribute declaration under `app` and `lib`. A read-only `RAILS_ENV=test bin/rails runner` inspection reported `client_oidc_subject_column=false` and `operator_oidc_subject_column=false` for the current local test databases.

These checks narrow the current local mapping but do not establish every possible runtime method, other environment's schema or deployed data. The Base resolver must still verify issuer, realm, audience, session and canonical round-trip, enforce actor lifecycle and preserve the non-Base RP boundary. No resolver was implemented or connected in this inspection.
