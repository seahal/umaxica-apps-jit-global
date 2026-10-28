# Isolated CookieStore refusal investigation

- Date: 2026-10-28.
- Repository commit: `b6e7871073bdc43a55fc5f05e8476de8ee71252f`.
- Worktree: pre-existing uncommitted application, configuration, locale, ADR and test changes were
  present. The experiment did not load the Rails application, its configuration, models or database;
  those application changes did not participate. `two.md` and `zero.md` are ignored working documents.
- Scope: synthetic in-memory Rack requests through installed ActionDispatch CookieStore and Cookies
  middleware. No network, real browser, real credentials, application data or DB was used.
- Dependencies: Rails/ActionPack `3fae946e765911d05755496f68c4578c7bc15476` / 8.2.0.alpha,
  rack-session 2.1.2, Rack 3.1.22, from the local bundle.
- Command: `bundle exec ruby /tmp/umaxica-cookie-grill.rb`.
- Final temporary harness SHA-256: `434a9d26c880d431fb9aedc907a964c3389ad95f7c8724abab257f7a3048c0c6`.
  The harness is a disposable diagnostic, not an application implementation or committed test.

## Setup

The stack was `ActionDispatch::Cookies` wrapping `ActionDispatch::Session::CookieStore`, with a
synthetic encryption key, HTTPS mock origin, host-only Secure/HttpOnly session cookie, SameSite Lax,
and `expire_after: 1209600`. Rack::MockRequest supplied in-memory requests. JSON session serialization
was used normally; a separate Marshal-to-hybrid case tested read-time reserialization. The fixture
stored only artificial flow labels A and B. No cookie values or key material are retained here.

## Observations

All 16 final checks passed (15 boolean conditions and the expected HTTP status 409):

- Reading session A while returning 409 issued a session cookie without explicit reset.
- A newer normal response carried B, while the delayed 409 cookie decoded to A; applying that stale
  cookie can replace the newer transport state.
- Per-request `session.options[:skip]` suppressed ordinary session commit, but did not suppress an
  explicitly queued auth SID cookie or a session cookie reserialized on read in the hybrid case.
- A prototype outer response filter, limited to the fixture's trusted refusal marker plus status 409
  and two exact authentication-cookie names, suppressed all three fixture issuance paths. An unrelated
  display cookie, normal-success session cookie and reset response cookie were preserved.
- `reset_session` produced a new session without the old artificial flow and explicit auth SID
  deletion produced an expiry header. Replaying the pre-reset encrypted session cookie still decoded
  the old artificial flow: CookieStore reset is not server-side revocation of old cookie contents.

## Limits

This establishes framework behavior and a transport-filter feasibility example only. The fixture
filter is not approved production middleware. It does not prove application callback ordering,
CSRF/Origin handling, all authentication-cookie names, DB non-mutation, browser host/path behavior,
concurrent application transitions, logout or completed-account protection. The synthetic hybrid
configuration is an adversarial fixture, not a claim that the application currently enables hybrid
serialization. No real browser or application HTTP/DB tests ran. Public application acceptance
remains required after an implementation is authorized.
