# External Authentication Phase 1 Implementation Notes

> Superseded on 2026-07-31 by
> `notes/implementation/2026-07-31-three-provider-authentication-hardening.md` for Google identity
> authority and provider-token retention.

## Context

- Original plan: `plans/analysis/apple-google-external-authentication-architecture-audit.md`
- Implementation date: 2026-07-24
- Installed contracts:
  - `omniauth-apple` 1.4.0
  - `omniauth-google-oauth2` 1.2.2
  - `omniauth-oauth2` 1.9.0

## Decisions Made During Implementation

- Apple nonce enforcement remains owned by the pinned OmniAuth strategy boundary.
  - The real strategy accepted a signed ID token that omitted both `nonce` and the nonstandard
    `nonce_supported` claim even though the request had stored a nonce.
  - The supported strategy options provide no setting that makes nonce verification unconditional.
  - `ExternalAuthentication::Infrastructure::OmniauthAppleNonceEnforcement` therefore extends the
    strategy claim check and invokes the strategy's existing nonce verifier only when the Gem would
    otherwise skip it.
  - Signature, issuer, audience, issued-at, and expiration checks remain owned by the Gem.
  - No Controller, Concern, or Use Case performs protocol nonce verification.

- Google identity authority remains the UserInfo response exposed as the strategy's top-level UID.
  - The installed strategy decodes `extra.id_info` without signature verification.
  - A contract fixture proved that a different `extra.id_info.sub` does not replace the UserInfo
    subject returned as top-level UID.
  - Failed code exchange and failed UserInfo retrieval do not produce an accepted identity.

## Review Notes

- Provider HTTPS boundaries are replaced with local stubs; no external provider is contacted.
- Apple tests use generated signing keys, signed ID tokens, the installed strategy, and a stubbed
  JWKS fetch boundary.
- Google tests use the installed strategy with stubbed token-exchange and UserInfo HTTP boundaries.
- Mock AuthHash is not used as evidence for either provider contract.
- The Apple contract gate passed after the Infrastructure extension.
- The Google trust-boundary characterization passed without a production behavior change.
- Google remains configured for offline access in current production code until the ordered
  Google-simplification phase.

## Verification

- `bin/rails test test/contracts/omniauth_apple_strategy_contract_test.rb`
- `bin/rails test test/contracts/omniauth_google_strategy_contract_test.rb`
- Relevant Apple initializer, integration, provider-boundary, assertion, and regression-guard tests
- Targeted RuboCop for the Apple contract and extension

## Remaining Phase 1 Boundaries

- The provider/ceremony mismatch remains covered at the Rails integration boundary because it is an
  application ceremony contract, not a Google strategy responsibility.
- Authorization-code and UserInfo network behavior is stubbed locally. A controlled provider E2E
  remains a separate operational gate.
