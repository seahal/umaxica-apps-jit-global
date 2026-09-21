# Backend Transport TLS Enforcement

Accepted: 2026-09-20

## Context

PostgreSQL and Valkey carry application state that includes credentials, authorization codes,
authentication ceremony state, rate-limit state, and other security-sensitive data. Deployment
values must not be able to silently select plaintext or unverified transport for the production Rails
configuration.

The repository has no separate Rails staging environment. Staging that uses the production Rails
configuration is therefore covered by the production rule below. Development and test retain their
local plaintext service topology so the local container contract remains usable.

## Decision

- Production Rails PostgreSQL writer and reader connections accept only `verify-full` for
  `NEON_PGSSLMODE` and `NEON_REPLICA_PGSSLMODE`. Any other value fails configuration evaluation and
  names the offending variable.
- Production Rails Valkey responsibilities (`CACHE_REDIS_URL`, `RATE_LIMIT_REDIS_URL`, and
  `AUTH_STATE_REDIS_URL`) must use `rediss://`. A `redis://` URL fails configuration evaluation and
  names the offending variable.
- Development and test keep their existing `redis://` service topology. This decision does not
  change local container TLS or invent a local certificate authority.
- The application does not change provider credentials, certificate bundles, database placement,
  external endpoints, or deployment configuration in this change.

## Consequences and limits

The application now fails closed at configuration time when these production transport contracts
are misconfigured. This is a configuration guard, not proof that a deployed provider presents the
correct certificate or that a live endpoint is reachable. Provider support, certificate bundle
distribution, and successful production/staging handshakes remain deployment verification items.

The existing outbound HTTP policy remains call-site based: provider and registry destinations must
state their HTTPS requirement through `OutboundHttp::Connection`; this decision does not add a
redirect-following or certificate-bypass path.

## Supersession and rollback

This decision supersedes the permissive production behavior that accepted any PostgreSQL `sslmode`
and either Valkey URL scheme. A rollback that re-enables plaintext production transport is not a
safe security rollback; an operational rollback must correct the deployment values or provide a
reviewed certificate/provider exception instead.
