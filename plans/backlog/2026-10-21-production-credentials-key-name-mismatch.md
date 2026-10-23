# Production Credentials Use Key Names the Code No Longer Reads

Recorded 2026-10-21 at `febec3225cc9a0cfa53b9cbe817d20d366aba5a2` (worktree with uncommitted
changes; none touch credentials or the JWT registry). Status: backlog, **high priority**. Outside the
current Visa separation plan (`two.md` WU-02); the owner asked for it to be kept here and handled
later. Nothing has been deployed, so no live system is affected yet.

## Problem

The encrypted credentials hold JWT and OIDC client keys under old names (Acme, Sign and older family names),
while the code reads the current names (Base, Auth, Warp, Palm …). In development and test this is
invisible, because `JitSecurityJwtLocalKeysetInstaller` generates every key at boot and writes it to
`ENV`, and `ENV` wins over credentials. In production the installer does not run, so the keys the
code needs are not there and the ones that are there are not used.

## What was observed (key names only; no values were printed)

Credentials files: `config/credentials/{development,test,production}.yml.enc`. Lookup path:
`JitSecurityJwtKeySource#value` returns `ENV[name].presence || Rails.app.creds.option(name)`;
`Rails.app.creds` is `ActiveSupport::CombinedConfiguration` of ENV (+ `.env` in development) and the
encrypted credentials (`railties/lib/rails/application.rb:530` in the vendored Rails).

| Names the code reads (`lib/jit_security_jwt_registry.rb`) | In production credentials |
|---|---|
| `JWT_BASE_{APP,COM,ORG}_{ACTIVE_KID,PRIVATE_KEY,PUBLIC_KEYSET}` | missing |
| `JWT_AUTH_{APP,COM,ORG}_*` | missing (`JWT_SIGN_*` present instead) |
| `JWT_WARP_{APP,COM,ORG}_*`, `JWT_PALM_APP_*` | missing |
| `JWT_CORE_{APP,COM,ORG}_*` | present |
| `JWT_ACME_{APP,COM,ORG}_*` | present, but see below |
| `OIDC_CLIENT_<namespace>_{ACTIVE_KID,PRIVATE_KEY}` for `OIDC_CLIENT_NAMESPACES` (e.g. `BASE_RP_APP_WW`, `WARP_APP_JP`, `TECH_ORG_WW`) | missing (`OIDC_CLIENT_SECRETS_{APEX,CORE,DOCS,HELP,NEWS}_{APP,COM,ORG}` present instead) |
| `AUTH_JWT_*`, `PREFERENCE_JWT_*` | present |

The test credentials hold only `JWT_{ACME,CORE,SIGN}_*_PRIVATE_KEY` of those families; development
mirrors production.

`ACME_*` is the old name of Base. The registry still lists `ACME_{APP,COM,ORG}` in
`SURFACE_NAMESPACES` and `OIDC_CLIENT_NAMESPACES` and maps them to `https://www.umaxica.*` in
`SURFACE_ISSUER_ORIGINS`, so the keys are loaded at boot. No code in `app/`, `lib/` or `config/`
asks for `surface:ACME_*`: the ceremony contracts' `acme_issuer_id` returns `surface:BASE_*`,
`AuthenticationJwtTokens#auth_jwt_namespace` derives the namespace from the controller path
(there is no `app/controllers/acme/`), and Jump RTs use `BASE_*`. Only test fixtures set
`JWT_ACME_*` (`test/controllers/concerns/oidc/sso_initiator_test.rb`,
`test/controllers/concerns/oidc/callback_test.rb`).

Not verified: how a production boot behaves with these names. Surface records are built even when
the key material is absent (`JitSecurityJwtIssuerBuilder.build_surface_issuer_record`), so a missing
surface key may surface only when something signs; required OIDC client keys are checked at boot
(`require_oidc_client_key_material!`). No production boot was attempted.

## Likely cause

The code was renamed (Acme → Base, Sign → Auth, client namespaces reorganized) without renaming or
reissuing the credentials. The local installer hid the gap.

## Work to do

1. Inventory every key name the code reads (registry, installer, `AUTH_JWT_*`, `PREFERENCE_JWT_*`,
   OmniAuth, social ceremony HMAC, any other `Rails.app.creds` reader) and compare with each
   environment's credentials, names only.
2. Remove the dead `ACME_*` namespace from the registry, the installer and the test fixtures (code
   change, with tests).
3. Owner: generate new ES384 (P-384) key material for the current names (and `JWT_VISA_*` once the
   Visa separation lands) and rewrite the production credentials; delete the old names. Do not
   reuse the old keys under new names without a decision.
4. Add a production-mode check that fails closed when a required key is missing, run it, and record
   the result in `evidence/` (environment setup is verified by running it, not by Minitest —
   `.agents/harnesses/rules/project/no-environment-tests.mdc`).
5. Decide whether development and test should keep the generated keys (current design) or read
   credentials; the installer shadows credentials today.

## Handling

Never print key values in logs, evidence or chat. `bin/rails credentials:show --environment <env>`
shows the values; run it only in a private terminal.

Related: one.md D-15 (one credentials set per environment), D-17 (AWS KMS direction), `two.md`
WU-02 D-K (Visa keys).
