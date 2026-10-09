---
name: observability-and-instrumentation
description: Design and inspect signals for a concrete production failure mode or new I/O boundary. Use for telemetry changes, incident diagnosability or alert design, not automatic instrumentation of every edit.
---

# Observability and instrumentation

Read `adr/application-logging-boundary.md` and `docs/security/observability-boundary.md` before
choosing signals. State the operator question and failure mode each signal should answer. Reuse the
existing pipeline; logging libraries and exporter setup are not implied by this workflow.

Distinguish authoritative persisted records from diagnostic telemetry. Use bounded attributes and
stable event names; propagate explicitly scoped context. Never place secrets, cookies, tokens,
authorization data or full request parameters in output. Redaction after disclosure is insufficient.

Exercise successful and failed paths with synthetic data and inspect the actual emitted result.
Measure cardinality and overhead when material. Alerts need an owner, actionable symptom, justified
threshold and response guidance; test delivery only within authorized environments. Record what
was observed and what remains unverified. A configured exporter does not prove receipt or safe retention.
