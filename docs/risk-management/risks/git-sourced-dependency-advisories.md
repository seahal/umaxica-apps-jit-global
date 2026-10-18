# Git-sourced dependency advisory coverage

Status: active
Response: accept (historically recorded Rails scope only; see decision below)
Risk Owner: not identified by the existing decision; assignment remains open.
Acceptance authority: not named in the existing decision; this record grants no new acceptance.

## Scenario and basis

Version-range advisory scans can provide incomplete coverage for dependencies pinned to Git
revisions. A clean scanner result therefore does not establish that the pinned code contains no
known vulnerable changes. The local `Gemfile.lock` still contains Rails, Propshaft and Flipper Git
sources at the time this record was created. No current upstream advisory or release lookup was
performed in this local-only migration.

The [accepted decision](../../../adr/git-sourced-rails-advisory-risk-acceptance.md) records a
2026-09-19 Rails acceptance until the Rails 8.2 release, and a gap for the other dependencies without
the same exit condition. Preserve that historical scope; do not extend it to other gems or infer
that its time condition still holds without checking current release facts.

## Assessment and response

- Likelihood: not assessed in this migration; depends on actual vulnerable revisions and reachability.
- Impact: potentially security-critical application compromise; assess against a concrete advisory.
- Existing measures: lockfile revision pinning makes the installed source identifiable; existing
  dependency scan jobs cover their supported sources. Pinning alone does not close advisory gaps.
- Residual risk: an affected Git pin can remain undetected by version-oriented scans.
- Acceptance rationale: the existing ADR elects to retain pre-release Rails; this record does not
  reapprove the decision or certify other Git dependencies.
- Review triggers: Rails 8.2 availability, a relevant advisory, any Git pin/source change, or an owner
  assignment. Verify the release condition before relying on the historical acceptance today.
- Review date: not assigned; the responsible owner must set it when ownership is established.

The historical [ASVS evidence](../../../evidence/2026-09-19-owasp-asvs-5-checklist-review-V5R8.md)
records the original finding. It is not a fresh dependency scan. Controls remain linked to their
existing implementation; no separate control document is needed yet.
