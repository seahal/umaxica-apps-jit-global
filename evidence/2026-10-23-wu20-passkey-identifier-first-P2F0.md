# WU-20: Passkey identifier-first, account label, ORG discoverable (D-112, D-116, D-171)

Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72` with the uncommitted cycle changes, after WU-01.

## Changes

- `PasskeySignInFlow#options` requires `identifier` on every surface. On APP/COM it resolves
  through the new `PasskeySignInIdentityResolverQuery` (effective Email/Telephone binding of the
  same surface). `allowCredentials` stays empty on APP/COM. An unknown identifier binds the
  challenge to `<surface>:0`. The discoverable no-actor branch (`discoverable_direct_passkey_sign_in?`)
  is removed, so verification always requires owner equality.
- `PasskeySignInPanel.tsx` renders the identifier field and submits its value; APP/COM pages pass
  `identifier_param: "identifier"` and a field. New locale keys
  `sign.com.authentication.passkey.new.pii_{label,placeholder}` (4 files, copied from APP). This also
  fixes ORG Emergency, whose panel previously always sent an empty identifier.
- `Webauthn::Surface#account_label` (`umaxica.app/.com/.org`) is used as `user.name`/`displayName`;
  `passkey_resource_display_name` is removed.
- Registration options request `credProps`; `RegistrationVerifier.verify!(…, surface:)` refuses an
  ORG credential not reported `rk: true` (`DiscoverableCredentialRequiredError`).
- `docs/security/passkeys.md` written; `webauthn-architecture.md` points to it.

## Runs

- `test/controllers/auth/{app,com}/in/passkeys_controller_test.rb`: 17 + 13 runs, 0 failures. Covers:
  - identifier-bound challenge;
  - unknown identifier: same shape, `:0` binding;
  - missing identifier: 422;
  - telephone selection;
  - another Identity's credential: 401.
- `test/queries/passkey_sign_in_identity_resolver_query_test.rb`: 13 runs, 0 failures.
- `test/unit/webauthn/verifiers_test.rb` and the related verifier tests: 35 runs, 0 failures. Covers ORG
  `rk` missing/false refused, `rk: true` accepted, and `credProps` requested on all surfaces.
- Sign-up options test asserts the label: passes.
- Passkey-related groups: 223 runs, 5 failures. Registration-related groups: 427 runs, 11 failures.
  Every failure in both groups is in G-1.
- `bun run test` 1159 passed; `bun run typecheck` exit 0; `bun run lint` clean; rubocop clean.

## Not verified

- A20-7 timing evidence (no measurement).
- End-to-end APP/COM dashboard Passkey journeys: they are G-1 failures
  (`BaseDashboardPasskeyLoginJourneyTest`), so identifier-first is unverified through them.
- A20-11 is asserted only for sign-up registration options, not Base management or ORG
  registration requests.
- A20-12 is checked at verifier level, not by a request test.
- Real browsers: whether each one reports `credProps` is not tested. An ORG authenticator or browser
  without `credProps` support can no longer register.
