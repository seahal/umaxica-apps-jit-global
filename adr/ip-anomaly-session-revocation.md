# IP/ASN-Anomaly Session Revocation

## Status

Accepted (2026-06-11)

Supersedes section 7 ("IP / UA / device as risk signal") of
`adr/session-token-hardening-baseline.md` for the specific case described below. Implemented in
Phase C of the token-theft defense hardening plan (since removed); the revocation behavior ships
behind a default-off feature flag for staged rollout (see Decision point 3).

## Context

`adr/session-token-hardening-baseline.md` §7 states that IP and User-Agent are used only for audit
and risk evaluation and "must never hard-invalidate a session on their own." That rule was chosen to
avoid false-positive logouts from ordinary IP churn (mobile networks, NAT, carrier rotation).

The token-theft audit identified that an infostealer-stolen cookie replayed from a different network
is currently only caught indirectly by refresh-reuse detection. The platform owner decided to add a
direct signal: a same-session change of the client's **coarse network** should be treatable as a
compromise indicator that hard-revokes the session, accepting the operational tradeoff.

This decision deliberately overrides the §7 prohibition for this narrow, coarse-grained, and
feature-flagged case.

## Decision

1. Track a coarse, privacy-preserving network fingerprint per device_session: `last_network_hmac` =
   HMAC of the **/24 (IPv4) or /48 (IPv6)** network (never the full IP), using the existing
   `OccurrenceHmac` secret. Full IPs are still never stored.
2. On refresh, if the presenting request's network HMAC differs from the stored one within the risk
   window, emit a `ip_change_detected` risk event.
3. Under the feature flag `IP_ANOMALY_REVOKE_ENABLED` (default OFF everywhere, including production;
   opt in via the env var or `config.x.ip_anomaly_revoke.enabled`), this event scores ≥100 in
   `SignRiskEngine` and triggers a full `token.revoke!` via `SignRiskEnforcer`. The flag defaults
   off so the mobile-network false-positive rate can be measured before any default-on decision.
   With the flag off, behavior is unchanged from §7 (the event is recorded as a signal only and does
   not score).

## Consequences

- **Positive:** A stolen cookie replayed from another network is severed on its first refresh from a
  different /24 or /48, not only when reuse races the legitimate client.
- **Negative / risk:** Legitimate network changes (Wi-Fi↔cellular, carrier rotation, VPN toggling)
  can trigger logout. Mitigations: coarse network granularity (/24, /48) tolerates most in-carrier
  churn; the behavior is feature-flagged for staged rollout with monitoring of false-positive rates
  before any default-on decision; revocation forces re-authentication (no data loss).
- IPv6 privacy extensions rotate the host portion but generally keep the /48 prefix, so /48
  granularity avoids most IPv6 false positives.
- This ADR does not relax §7 for User-Agent: UA changes remain signal-only.

## Implementation

Touch points: device-session schema (additive, nullable, reversible migration for
`last_network_hmac`), `OccurrenceHmac` network helper, `app/services/sign_risk_emitter.rb`,
`app/services/sign_risk_engine.rb`, `app/services/sign_risk_enforcer.rb`. Tests extend
`test/services/sign/risk/*`.
