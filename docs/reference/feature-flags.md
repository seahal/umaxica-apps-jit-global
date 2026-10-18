# Feature Flags

Flags are stored in Flipper (PostgreSQL `primary` database, see `config/initializers/flipper.rb`)
and toggled through the Flipper UI mounted on the developer surface. They are runtime operational
controls, not deploy-time configuration: required configuration still uses `ENV.fetch("NAME")` and
fails at boot when missing.

## Polarity

Two polarities are in use, and the direction is a deliberate per-flag decision:

- **Availability flags** (`social_ceremony_*`): an unset or unknown feature reads as **disabled**.
  Losing the flag store must stop external authentication ceremonies rather than let them through.
- **Suspension flags** (`outbound_*_suspended`, `turnstile_degraded_mode`): an unset feature reads
  as **not suspended**, so a flag store that was never written does not take delivery or sign-in
  down. The operator turns the flag on during an incident.

## Flags

| Flag                                   | Polarity     | Effect                                                                                                                                                                               |
| -------------------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `social_ceremony_app_apple`            | availability | Enables Apple sign-in on the `app` surface. Unset stops new ceremonies; issued callbacks drain.                                                                                      |
| `social_ceremony_app_google`           | availability | Same, for Google on `app`.                                                                                                                                                           |
| `social_ceremony_org_entra`            | availability | Same, for Microsoft Entra ID on `org`.                                                                                                                                               |
| `outbound_sms_suspended`               | suspension   | Stops all outbound SMS (`OutboundSms`). Delivery returns a rejected `OutboundResult`; no SNS call and no job is enqueued.                                                            |
| `outbound_email_suspended`             | suspension   | Stops all outbound email, transactional and promotional, through the ActionMailer interceptor.                                                                                       |
| `outbound_promotional_email_suspended` | suspension   | Stops promotional mail only (`*::PromotionalMailer`). Transactional mail keeps delivering.                                                                                           |
| `fqdn_available_<slot>`                | availability | One flag per served FQDN slot (`fqdn_available_base_service`, `fqdn_available_auth_staff`, …). Off or unset returns `503` before rate limiting and before authentication. See below. |
| `turnstile_degraded_mode`              | suspension   | Treats a Turnstile verification that failed **because Cloudflare was unreachable** as a pass. A failed challenge, a missing token, and a missing secret key are still rejected.      |

`turnstile_degraded_mode` weakens a bot-defence control while it is on. It exists so a Cloudflare
outage does not close sign-up and sign-in, and it is meant to be turned back off when the incident
ends.

## Per-FQDN availability

`fqdn_available_<slot>` is the operator kill switch for one fully qualified domain name. The slot
list and the hostnames that reach each slot are in `app/values/fqdn_availability_registry.rb`, which
mirrors the `constraints(host:)` declarations in `config/routes/*.rb`;
`Security::Invariants::FqdnAvailabilityRegistryInvariantTest` fails when the two drift.

`FqdnAvailabilityGate` (`app/controllers/concerns/fqdn_availability_gate.rb`) consults the flag as
the first `before_action` on every surface base controller, so a switched-off FQDN never reaches the
rate limiter, the session, authentication, or a controller action:

```text
request -> FQDN availability gate -> rate limit -> context/preference -> authentication -> action
```

The feature name is selected from the registry slot, never from the `Host` header. A hostname with
no slot is refused. Because the polarity is `availability`, a feature that was never written reads
as off, and a flag store that raises is treated as unavailable rather than as permission.

`/health` and everything beneath it are exempt: `adr/internal-health-endpoint-edge-isolation.md`
defines them as internal orchestrator probes, and switching a public FQDN off must not also blind
the probes that report why. Turning a slot off is therefore invisible to liveness and readiness.

New FQDNs need a registry entry; the registry derives the flag name, so no second list to update.

## Operational notes

- Suspending SMS or email does not tell the user why their code never arrived; the request path
  reports an ordinary delivery failure. Treat the flags as incident tooling.
- Per-request degrade and suspension decisions are logged as telemetry only. The durable record that
  a switch was pulled is the Flipper feature row itself; treat that, together with the incident
  record, as the authoritative history.
- `db/seeds.rb` registers the `social_ceremony_*` and `fqdn_available_*` flags in development only,
  because both are availability flags and an unwritten flag closes the ceremony or the FQDN.
  Suspension flags are deliberately not seeded: their default is off, and Flipper reads an unwritten
  feature as off.
- Production is never seeded. Turning a public FQDN on there is an explicit operator action through
  the Flipper UI (`/flipper` on the developer host), which is a mounted Rack app and therefore not
  itself behind the FQDN gate.
