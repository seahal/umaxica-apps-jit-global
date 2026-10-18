---
name: security-and-hardening
description: Threat-model and review sensitive changes to identity, authorization, secrets, trust boundaries or untrusted execution. Use for a concrete security change or audit, not every ordinary edit.
---

# Security and hardening

Load the affected security rules through `AGENTS.md`, the accepted contract and durable checklist.
Map the assets, actors, entry points and surface boundaries. Identify what an attacker can control,
then write abuse cases beside successful behavior. Preserve the ordering of admission,
authentication, authorization, CSRF, rate limits and final mutations.

For adversarial review of a high-impact decision, ask: which invariant could fail under replay,
races, partial failure or stale authority? What observation would falsify the design? Which recovery
operation is irreversible? Use a separate agent only when authorized and its independent scope
justifies the cost; it is not a default review gate.

Use [security review prompts](references/security-checklist.md) only for relevant attack surfaces.
Verify via public interfaces, including refusals and boundary cases. Distinguish requirements from
observations and state coverage limits. Logs and retained evidence must not expose credentials or
sensitive request data. Existing authorization applies; external incident reporting, rotation and
production changes require their own scope and authority.
