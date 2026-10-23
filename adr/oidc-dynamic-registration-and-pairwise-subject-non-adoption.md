# OIDC Dynamic Client Registration and Pairwise Subject Identifier Non-Adoption

## Status

**Accepted (2026-10-24).** Owner decision; documentation only. These are intentional current
non-adoption decisions, not permanent prohibitions or implementation backlog commitments.

This ADR supplements [RP scope](oidc-rp-scope-umaxica-tlds-only.md),
[Base/Auth boundary](base-auth-ceremony-and-seven-rp-boundary.md), and
[OIDC claims](oidc-claims-decision.md). It supersedes no accepted decision. It changes no code,
routes, registrations, Discovery, persistence, existing subject values, or RP admission scope.

## Context and architectural boundaries

The OP currently admits only explicitly registered first-party RPs on `umaxica.app`, `umaxica.com`,
and `umaxica.org`. A host on one of these domains is not automatically an admitted client.
Every other domain is external, including UMAXICA-owned `umaxica.dev` and `umaxica.net`.
External RPs, including third-party RPs, are not currently admitted directly. External-system
integration normally goes through `tech.umaxica.org`, under
[Tech and Palm participation](tech-and-palm-browser-rp-participation.md); it does not register the
external system as an OP client.

The Base/Auth ADR assigns the physical OIDC OP / Authorization Server implementation to Base.
The later [OP/Auth/RP responsibility separation](op-auth-rp-authentication-responsibility-separation.md)
partially supersedes that combined model: the OP owns OIDC and application Base is logically an
RP. This ADR preserves that newer responsibility decision and does not require physical co-location
or claim that its migration is complete. APP, COM, and ORG remain independent trust boundaries.
The existing [Identity boundary](identity-authority-boundary.md),
[credential binding](identity-resolution-and-credential-binding.md), and
[Identity-centric AAA](identity-centric-aaa-architecture.md) decisions retain their scoped ownership.

Standards-compatible OP contracts are an extensibility goal, separate from an operational decision
to accept external RPs. The first-party scope, rather than a standards prohibition, motivates both
decisions below.

## D1: Dynamic Client Registration is not adopted

UMAXICA currently provides no Dynamic Client Registration under RFC 7591. Client registration
continues through the existing static Client Registry and explicit allowlist.

1. Admitted RPs are managed first-party clients; they need no third-party automatic registration.
2. Static registration and explicit admission already satisfy the current requirements.
3. A registration API would add attack surface, metadata validation, and operational burden.
4. Client review, lifecycle management, and registration authorization introduce responsibilities
   for which the current scope supplies no sufficient requirement.

Dynamic Client Registration is not required to use the basic OIDC Authorization Code Flow.
Statically registered RPs continue to use ordinary OIDC authentication. This is a deployment choice,
not a claim that dynamic registration is incompatible with first-party operation. RFC 7591 also
permits protected registration with restricted authorization; dynamic registration does not mean
unlimited public registration.

Moving registration metadata into a database or exposing an administrator management API would not,
by itself, adopt the standard Dynamic Client Registration protocol. A clear requirement to provide
external RPs with a standard Client Registration API requires a separate adoption ADR. Even if
external RPs are later admitted, continuing static registration remains an available choice;
external admission does not require Dynamic Client Registration.

## D2: Pairwise Subject Identifiers are not adopted

UMAXICA continues Public Subject Identifiers and the existing Discovery policy:

```json
{
  "subject_types_supported": ["public"]
}
```

1. Current RPs are first-party clients managed by UMAXICA.
2. Sector-based separation to prevent correlation across independent external RPs is not a current
   requirement, because those RPs are not admitted.
3. Public subjects satisfy the existing first-party identification requirements.
4. Pairwise generation, any required persistence, Sector management, and identifier migration add
   complexity without a current requirement.
5. Existing RP `sub` stability and compatibility take priority over an unneeded identifier change.

`public` names a Subject Identifier type; it does not mean the OP is publicly available.
Under OIDC Core, pairwise identifiers separate subjects by **Sector Identifier**, rather than
necessarily by individual RP: clients sharing a Sector can receive the same subject. Selecting
public subjects does not establish the absence of disclosure or privacy risks. It permits
correlation through a shared subject within the issuer; claim release, authorization, and other
privacy controls remain necessary.

RPs identify an End-User by the combination of validated Issuer (`iss`) and Subject (`sub`),
including when the subject type is public. A future pairwise design can map an internal canonical
Identity ID to sector-specific outward identifiers; adopting pairwise would not inherently require
changing that internal ID. This decision changes neither existing `sub` values nor their meaning.
Upstream providers' identifiers, including Entra subjects described in
[ORG Entra sign-in](org-entra-id-sign-in-boundary.md), are outside this OP issuance decision.

## Back-Channel Logout remains independent

[R5 OP commit and Back-Channel Logout for separated RP stores](first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md)
continues to govern its adoption and activation conditions. Its scoped supersession of the older
shared-database logout decision remains intact. Neither D1 nor D2 changes logout design,
registration bindings, delivery, receiver validation, or implementation policy. Static registration
and public subjects do not prevent Back-Channel Logout.

## Invariants

- The OP MUST admit only the first-party RPs authorized by the current RP scope ADRs.
- Direct external RP registration remains outside the currently permitted scope.
- Client registration MUST continue through the existing static management and explicit allowlist.
- The current endpoint set MUST remain free of a Dynamic Client Registration Endpoint.
- Subject issuance MUST continue using `public`, with existing `sub` values and meanings preserved.
- The current issuer MUST retain its existing subject generation without pairwise issuance.
- Discovery MUST retain `"subject_types_supported": ["public"]`.
- Back-Channel Logout MUST retain its independently accepted R5 policy.
- Any future direct external RP admission MUST have a separate accepted design decision.

## Reconsideration gates

Before approving the first direct third-party external RP connection, the Owner MUST reconsider
Public versus Pairwise Subject Identifiers and record the decision in a separate ADR. The review
is a mandatory design gate before admission approval, not a predetermined adoption of pairwise.
The review MUST evaluate:

- whether external RPs may receive a common `sub`;
- acceptable cross-RP user correlation;
- Sector Identifier ownership and management;
- compatibility with existing first-party RPs;
- subject persistence and user-account migration;
- identifiers retained by external RPs and applicable privacy requirements.

Any proposed external RP admission, including a UMAXICA-owned domain outside the three permitted
domains, also requires reevaluating this ADR's first-party-only rationale and the RP scope decision.
Dynamic Client Registration is reconsidered separately when a concrete standard registration API
requirement exists. Static registration may remain appropriate after external admission.

## Consistency review and limits

Reviewed on the local `feature` worktree at commit
`6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`, including pre-existing uncommitted changes:

- `app/values/oidc_client_stores_static_client_store.rb` constructs only its explicit first-party
  family/realm registrations, including Base self-RPs, Tech, and Palm; deployment bindings supply
  client IDs and configured hosts. This is not runtime proof of deployed host values or admission.
- `app/values/oidc_discovery_document.rb` declares `["public"]` and no `registration_endpoint`.
- `app/values/oidc_subject.rb` generates actor-prefixed subjects from `oidc_subject` or `public_id`,
  with no RP/Sector input. Token issuance uses this generator.
- `test/services/oidc/subject_test.rb` describes the existing prefixed subject contract;
  `test/services/oidc/discovery_document_test.rb` and the registry tests were inspected, not run.

No conflict with D1 or D2 was identified in those inspected sources. The newer logical OP/Base
separation qualifies the older physical-Base wording as noted above. Discovery currently omits
Back-Channel Logout support flags, and its existing test expects that omission; this observation
does not revise or certify delivery of the independently accepted R5 logout policy.
No tests, application boot, network deployment verification, or implementation changes are part of
this documentation decision. Future external admission and its identifier policy remain undecided.

## Primary standards

- [OIDC Core 1.0, Section 3.1](https://openid.net/specs/openid-connect-core-1_0-final.html#CodeFlowAuth)
  defines Authorization Code Flow; registration is a prerequisite, not a requirement to expose a
  dynamic registration API.
- [OIDC Core 1.0, Sections 8 and 8.1](https://openid.net/specs/openid-connect-core-1_0-final.html#SubjectIDTypes)
  define public/pairwise subjects and Sector-based calculation;
  [Section 5.7](https://openid.net/specs/openid-connect-core-1_0-final.html#ClaimStability)
  defines the stable issuer-and-subject identity combination.
- [RFC 7591, Section 3 and Appendix A.1](https://www.rfc-editor.org/rfc/rfc7591)
  defines registration and distinguishes open from protected registration.
- [OIDC Discovery 1.0, Section 3](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata)
  defines `subject_types_supported` and the recommended `registration_endpoint` metadata for an
  OP supporting dynamic registration. These standards describe capabilities; UMAXICA's current
  non-adoption reasons and admission gates are local architectural decisions.
