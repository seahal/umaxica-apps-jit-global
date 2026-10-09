# XT to Away External Navigation Gateway

**Status: Future plan; implementation deferred.**

## Direction

In the future, `xt` (External Target) is intended to route navigation to external sites through
`https://away.umaxica.net`. Away would operate in an independent, isolated environment and provide
an interstitial screen before the user proceeds to an external site.

This proposal does not change the current redirect contracts described in
[Redirect Targets](../../docs/security/redirect_targets.md) and
[Redirect Target Lanes](../../adr/redirect-target-lanes-pt-nt-xt.md).

## Relationship to Jump RT

The existing signed `rt` mechanism at `jump.umaxica.net` is the reference for the following security
properties:

- Signature verification of navigation authorization.
- Explicit separation of issuer, audience, and purpose.
- Short expiration and replay prevention where required.
- Navigation only to permitted destinations.
- Rejection of invalid or expired tokens.

Jump RT and Away authorization would remain separate by purpose. Neither would unconditionally
accept the other's authorization information.

## Responsibilities

- **XT:** external destination selection and permission policy.
- **Jump:** the existing signed navigation mechanism and its authorization boundary.
- **Away:** the external-navigation interstitial and verification of the authorization result.

A future ADR will determine the concrete connection between Jump and Away. This proposal leaves that
integration undecided.

## Current Scope and Future Review

The current `/sign` revision leaves XT, Jump, and Away implementations unchanged. Its priorities are
the `app`, `com`, and `org` authentication entry points, Preference inconsistencies, cancellation
handling, and a safety audit of the existing PT/NT paths.

Away development will require a separate design review that references this plan before
implementation begins. This document records future intent only; it does not authorize or deliver an
implementation.
