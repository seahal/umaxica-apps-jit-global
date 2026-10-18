# Project Issue Review Follow-Up

Date: 2026-06-06

This note records follow-up decisions from the project issue review pass.

## Authentication::Base split

`app/controllers/concerns/authentication/base.rb` remains too large for routine review. Do not split
it by moving callbacks first. The next extraction should preserve the current lifecycle order and
move private helper clusters behind existing concern boundaries:

- token encode/decode helpers into `Authentication::JwtTokens` / `Authentication::TokenService`;
- policy DSL and skip guardrails into a policy-boundary concern;
- session checkpoint helpers into the existing sequence/session concerns;
- residual cookie/token I/O into the existing cookie/token service concerns.

Before each extraction, run the authentication concern tests and the security invariant tests that
pin skip guardrails and controller boundary behavior.

## Dynamic dispatch audit

The largest `public_send` clusters are route-helper fanout in tests/views, preference association
fanout, and configurable ceremony/identity code. Treat route helper fanout and configuration-backed
association access as audited dynamic dispatch unless a local explicit helper already exists.
Prioritize replacement only where the receiver and method are fixed by one concrete surface.

## Acme application controller lifecycle

The app/org/com Acme base controllers intentionally spell out the callback order. The FIXME comments
around includes and callbacks are not safe to resolve by moving includes or callbacks in isolation.
Future cleanup should first introduce a lifecycle inventory test that compares app/org/com callback
order, then replace subjective comments with factual ownership notes.

## N+1 audit

Activity pages now use surface-local activity log services and chronicle preload scopes where known.
Any further N+1 work should be measurement-driven against settings activity/session pages before
adding more eager loading.
