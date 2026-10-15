# Tech operational procedure deliverable

Recorded on 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with
uncommitted documentation changes. The session began against
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`; HEAD changed externally during this work, and the final
link/diff check observed the newer commit. This agent made no commit.

REQ-054 requires prepared external DNS/Tunnel/Access/key/initial-IAM and close-Tech recovery
procedures. The operations directory had no Tech procedure. Added
`docs/operations/tech-browser-rp-runbook.md` and linked it from the existing Operator capability
runbook. The document uses the current host/client registry, TECH_ORG key names, audited bootstrap
task and migration rollback refusal as its sources. It covers owners, staged publication, browser
acceptance scenarios, Tech-only traffic containment and history-preserving forward repair.

Reviewed `lib/jit_security_jwt_registry.rb`, `lib/tasks/operator_capabilities.rake`,
`OperatorCapabilityGrant.bootstrap!`, the Tech capability migration and the owning participation
ADR. Every relative link in the new document resolves; scoped tracked diff checking passed. The
initial Python link-check command could not execute because `python` is absent; the equivalent Ruby
check executed successfully. No external configuration, bootstrap mutation, production grant,
deployment, database migration or browser acceptance was performed. This completes a documentation
deliverable, not those separately owned operational actions.
