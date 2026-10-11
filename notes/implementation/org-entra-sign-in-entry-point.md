# Org Entra Sign-In Entry Point Implementation Notes

> **Superseded in part (2026-08-22).** The per-organization multi-tenant reasoning below —
> `UmaxicaEntra#active_connection_from_params`, `#configure_for_connection!`, the cushion page that
> exists because "there is no Entra tenant to send the operator to", and the `connection_public_id`
> / `?connection=` contract — was replaced by
> `adr/org-entra-single-tenant-credential-configuration.md` (accepted 2026-08-11). The tenant,
> client, and client secret now come from Rails credentials for a single tenant; the strategy has no
> connection-resolution methods and `Auth::Org::Social::SessionsController` carries no input. The
> button, availability gating, non-enumerable error parity, and title-only artwork decisions are
> unchanged and still govern. Retained as the record of why the entry point was built this way.

## Context

- Original plan/spec: add a Microsoft Entra ID sign-in entry point to
  `https://auth.umaxica.org/sign/in`, mirroring the Google/Apple buttons on the app surface's
  `/sign/in`. Sign-in only; no sign-up counterpart.
- Related decisions/docs/plans: `adr/org-entra-id-sign-in-boundary.md`,
  `adr/org-entra-omniauth-strategy-migration.md`,
  `docs/reference/third-party-sign-in-button-requirements.md`.
- Implementation date: 2026-08-04

The Entra ceremony (strategy, callback, session issuance, settings management) already existed and
worked end to end. Only the entry point was missing: nothing linked to `/social/entra/session/new`,
so the page was reachable only by someone who already had its URL.

## Decisions Made During Implementation

- Decision: keep one cushion page between the sign-in button and the OmniAuth request phase.
  - Why: Google and Apple use one application-wide `client_id`/secret from Rails credentials, so a
    single button can POST straight to the request phase. Entra is multi-tenant —
    `UmaxicaEntra#active_connection_from_params` / `#configure_for_connection!`
    (`lib/omniauth/strategies/umaxica_entra.rb:213-241`) resolve tenant, client id, and credential
    key per request from an `OrganizationEntraConnection`. Without a connection there is no Entra
    tenant to send the operator to.
  - Alternatives considered: a `common`/`organizations` multi-tenant Entra app registration would
    allow literal Google/Apple parity with a single button, but it replaces the per-organization
    connection model that `adr/org-entra-id-sign-in-boundary.md` accepted, needs a single shared app
    registration, and widens the tenant trust boundary. Rejected as out of scope for an entry-point
    change; revisit only via a new ADR.
  - Follow-up needed: none for this change.

- Decision: `Social::SessionsController#create` serves both the button's first arrival (no
  connection → render the cushion page) and the cushion form's submission (connection → 307 to
  `/social/entra`).
  - Why: lets the sign-in page use the same `auth/shared/_social_provider_button` partial and the
    same POST plumbing as the app surface, so the button markup and CSRF handling stay identical.
  - Alternatives considered: a plain `link_to` to `#new`. Rejected — it would diverge from the app
    surface's button treatment for no gain.

- Decision: unknown, revoked, and malformed connection identifiers all produce the same status,
  message, and markup (`sign.org.authentication.entra.new.connection_not_found`).
  - Why: distinguishable responses would let an unauthenticated caller enumerate which organizations
    have Entra configured. Covered by a test that asserts parity between the unknown and revoked
    cases.

- Decision: gate the entry point on `ProviderSurfacePolicy` plus
  `external_authentication_start_available?` (the `:social_ceremony_org_entra` Flipper feature), not
  only on the strategy's own gate.
  - Why: without it, a kill switch during an incident would still render a live-looking button and
    only fail after the operator pressed it. Mirrors `UmaxicaEntra#entra_start_available?`.

- Decision: `#create` accepts `connection_public_id`, and `#new` continues to accept the existing
  `?connection=` link contract used by `Auth::Org::Settings::EntrasController#create`.
  - Why: preserving the existing administrator-distributed URL shape; both go through one private
    `requested_connection_public_id` reader.

- Decision: the Entra button renders title-only, via the shared partial's generic `else` branch.
  - Why: `docs/reference/third-party-sign-in-button-requirements.md` forbids redrawn provider
    artwork, and no Microsoft artwork is in the repository. This matches how the Apple button
    degrades when `apple_sign_in_logo_paths` is nil.
  - Follow-up needed: if Microsoft's official artwork is added under `public/images/social/`, give
    the partial an `entra` branch the same way Google and Apple have one.

- Decision: the passkey link, secret-credential link, and Entra button are siblings in one
  `ul.sign-in-methods`, replacing the previous bare `div` of links plus a separate
  `ul.social-provider-buttons`.
  - Why: every entry is one sign-in method, so they belong on the same line and in the same list.
    Requested after the entry point landed.

- Decision: `/sign/in` and `/sign/up` link to each other, but only on direct entry — the links are
  gated on `@oidc_authorization_intent.blank?`.
  - Why: `Auth::Org::Sign::{Ins,Ups}Controller#show` set that ivar only for an RP-initiated local
    ceremony. `test/controllers/auth/org/sign_ins_controller_test.rb` already asserted "local
    ceremony does not render sign up link on sign in page" — an RP that asked for a sign-in must not
    be offered a detour into sign-up. The reciprocal link on the sign-up page follows the same rule,
    which is now asserted too.
  - Alternatives considered: unconditional links; rejected because they break that existing
    contract.

## Deviations From Plan

- Change: `config/locales/us/en.yml` received the whole `sign.org.authentication.entra` block, not
  just the new keys.
  - Why: that file had no `entra` block at all, so every string on the ceremony and error pages was
    missing for that region. The page was previously unreachable from the UI, which hid the gap; the
    new entry point makes it reachable.
  - Risk: none — additive, mirrored verbatim from `config/locales/jp/en.yml`.

- Change: both English locale files also received the whole `sign.org.ups` block.
  - Why: same shape of gap. `sign.org.ups` was Japanese-only, so the org sign-up page had no English
    strings at all; the en files carry an unrelated `sign.org.registration` instead. Linking to that
    page from `/sign/in` makes the gap reachable from the main flow.
  - Risk: none — additive. It does not resolve the underlying `ups` vs `registration` key-tree
    divergence between the ja and en files, which remains as it was.

## Review Notes

- Follow-up work to promote into planning: the cushion page asks for the connection public id (a
  21-character nanoid), which is not memorable and in practice must be distributed by an
  administrator. Resolving the connection from an email domain or organization slug would remove
  that step, but no domain-to-connection resolver exists today. Deliberately out of scope here.

- Unrelated pre-existing failure observed, NOT caused by this change and NOT fixed here:
  `AuthSignCeremonyRouteContractTest#test_auth_app-only_route_contract` fails with
  `No route matches "http://auth.app.localhost/social/google/session/new"`. A separate in-flight
  change in the same worktree made the app-surface social ceremony start POST-only
  (`resource :session, only: :create`) on login-CSRF grounds (CVE-2015-9284); that test's assertions
  at `test/integration/routes/auth_sign_ceremony_route_contract_test.rb:335` are stale relative to
  it. Left for the author of that change. The org assertions in the same file pass.

- Tests run (all passing):
  - `test/controllers/auth/org/social/sessions_controller_test.rb` (new, 8 tests)
  - `test/controllers/auth/org/sign_ins_controller_test.rb`,
    `test/controllers/auth/org/sign_ups_controller_test.rb` (reciprocal links, both directions,
    present on direct entry and absent during a local ceremony)
  - `test/controllers/auth/org/` (221 tests)
  - `test/integration/routes/auth_sign_ceremony_route_contract_test.rb`
  - `test/integration/org_social_login_blocked_test.rb`,
    `test/integration/com_social_login_blocked_test.rb`,
    `test/integration/cross_surface_isolation_test.rb`
  - `test/security/invariants`, `test/unit/security/entra_omniauth_secret_filtering_test.rb`
  - `test/policies/external_authentication/provider_surface_policy_test.rb`
  - RuboCop on all touched Ruby files

- Tests not run: the app-surface social suites (`test/integration/social_auth_*`), since no
  app-surface or shared controller code changed. The one shared file touched,
  `app/views/auth/shared/_social_provider_button.html.erb`, changed only in its documentation
  comment.

- Manual end-to-end against a live Entra tenant was not performed; it needs an ACTIVE
  `OrganizationEntraConnection` and real Microsoft credentials.

- Documentation promotion needed: none. `adr/org-entra-id-sign-in-boundary.md` remains accurate —
  this change adds no provisioning, no sign-up path, and no new trust boundary.
