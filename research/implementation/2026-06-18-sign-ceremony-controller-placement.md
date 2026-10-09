# Sign Ceremony Controller Placement

The Sign app surface currently keeps newer ceremony controllers under nested `sign/app/sign/...`
namespaces, while Sign com/org retain older ceremony controller placement for their staff and
corporate flows.

This Phase 1 Rails-only remediation intentionally leaves that placement unchanged. The route table
and focused contract tests did not show a routing defect that requires namespace churn, and Sign
must remain a relying party rather than an issuer. A future cleanup should first define the desired
cross-surface ceremony naming contract and then migrate tests/routes/controllers together.
