# COM Auth and Visa host remnants after the `.com` authentication retirement

Status: Deferred; recorded at the owner's request on 2026-11-06. No implementation change is
authorized by this entry.

## Background

`.com` authentication has been retired. `config/routes/auth.rb` and `config/routes/visa.rb` (lines
7-9) constrain Auth and Visa to the `app` and `org` realms only; `app/controllers/auth/com/`, the
COM principal and OP databases, the COM RPs and the `sign_*_available_com` flags no longer exist.
The `com` surface itself remains: Base, Warp, Info, Help, Docs and News still route `com` hosts, and
those references are current, not remnants.

Code and configuration still carry the COM Auth (`sign_corporate` / `auth_corporate`) and COM Visa
(`visa_corporate`) host family. These hosts serve nothing.

## Remnants (static reading)

1. **Required boot configuration.**
   - `lib/config_values_host_family_values.rb:116,125` read `sign_corporate` and `visa_corporate`
     with one-argument `env.fetch`, so boot fails unless unused CORPORATE Auth/Visa URLs are set.
     The same file defines them in the host families (lines 10, 19, 46, 55, 60, 80).
   - `lib/config_values_oidc_authority_values.rb:14,24` list `corporate` as an OIDC authority.
   - `lib/jit_id_host_env.rb:14,24` treat a missing `AUTH_CORPORATE_URL` as a missing key.
2. **Allowlists (security-relevant: hosts that do not exist remain trusted).**
   - Redirect targets: `app/controllers/concerns/common_redirect.rb:134,140,142,145`;
     `app/resolvers/redirects_external_target_resolver.rb:9` (`idp` target).
   - Social callback hosts: `app/controllers/concerns/social_callback_guard.rb:122-124,133,141`;
     `config/initializers/omniauth.rb:203,233`.
   - CSP: `config/initializers/content_security_policy.rb:25,31`.
   - Host Authorization: `config/environments/production.rb:161,164,171` (including a literal
     `"auth.umaxica.com"`); `config/environments/development.rb:185,247,252,283,289,329`.
   - Back-channel and OIDC host checks: `app/lib/outbound_http/local_back_channel.rb:41`;
     `app/values/oidc_issuer.rb:51`; `app/controllers/concerns/oidc_callback.rb:120`.
3. **OIDC client and JWT registries.**
   - `app/values/oidc_client_registry.rb:224-236`;
     `app/values/oidc_client_stores_static_client_store.rb:188`.
   - `app/values/jump_rt_surface.rb:13,19,31` (`AUTH_COM`, `VISA_COM`).
   - `lib/jit_security_jwt_registry.rb:53,69` (`https://auth.umaxica.com`,
     `https://visa.umaxica.com`).
   - `app/values/fqdn_availability_registry.rb:28,35`.
4. **Comments only.** `app/resolvers/webauthn/relying_party_config_resolver.rb:8` and
   `config/initializers/webauthn.rb:7` mention `WEBAUTHN_<APP|COM|ORG>`;
   `app/values/webauthn/surface.rb` supports APP and ORG only.

## Follow-up when selected

- Remove the CORPORATE Auth/Visa host family together with every reader in one change, and update
  the environment contract in the same change (`.env*`, `.devcontainer/`, deployed secrets, README).
  Removing a required `ENV.fetch` changes the boot contract.
- Before removing `AUTH_COM` / `VISA_COM` from `lib/jit_security_jwt_registry.rb` and
  `app/values/jump_rt_surface.rb`, confirm that no issued token, JWKS or Jump flow still relies on
  them.
- Treat allowlist removals as security changes (`generic/absolute-rules.mdc`,
  `project/regression-guards.mdc`): add boundary tests showing that redirects, social callbacks and
  Host Authorization refuse the former COM Auth/Visa hosts while `app`/`org` hosts and the remaining
  `com` surfaces keep working.
- Keep the `com` surface hosts (Base, Warp, Info, Help, Docs, News) unchanged.

## Basis

Static reading on 2026-11-06 at `b30345216886c98af1f04cbd434f067f12decf01` with uncommitted changes
in the worktree. No tests or boot checks were run for this note.
