---
name: shipping-and-launch
description: Prepare and carry out an explicitly requested release with scoped checks, observability and recovery. Use for deployment or release readiness, not routine local feature implementation.
---

# Shipping and launch

Establish the intended environment, exact revision, release scope and existing authority. Read the
applicable operations runbook and open spec. Separate local verification from remote deployment;
prepare a concrete release result before requesting any still-required external approval.

Identify prerequisite configuration, migration compatibility, recovery steps, monitored failure
signals, rollback decision authority and stop conditions. Use existing pipelines and commands;
this Skill does not select a hosting vendor or add infrastructure.

Run risk-appropriate checks. A green build does not establish live authentication, telemetry or
migration safety. Record skipped and blocked checks. Deploy only within explicit authorization,
observe the agreed signals, and stop on the defined failure condition. Record revision, environment,
actual observations and rollback disposition without secrets. Update affected operations docs.
