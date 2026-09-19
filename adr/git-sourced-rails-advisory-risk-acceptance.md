# Git-Sourced Rails: Advisory Detection Risk Acceptance

Accepted: 2026-09-19

## Context

`Gemfile` sources Rails from GitHub rather than from a released gem:

```ruby
gem "rails", github: "rails/rails", branch: "main"
```

`Gemfile.lock` pins the revision (`6848556f777416f10279b7d6ceb371d56058214a` at the time of
writing, reporting version `8.2.0.alpha`). `propshaft`, `flipper`, `flipper-active_record`, and
`flipper-ui` are also sourced from GitHub.

The OWASP ASVS 5.0 review of 2026-09-19
(`evidence/2026-09-19-owasp-asvs-5-checklist-review-V5R8.md`, finding F2, ASVS 15.2) found that
vulnerability detection does not work for these dependencies:

- `bundle-audit` and the GitHub Advisory Database match advisories against released version ranges.
  A `main` revision reporting `8.2.0.alpha` is not in any advisory range, so a known vulnerability
  in the pinned revision produces no warning.
- Dependabot does not raise security alerts for git-sourced gems.
- The lockfile pin keeps the code reproducible and tamper-evident (the revision is a commit hash),
  but it also means that security fixes merged upstream after the pinned revision are not picked
  up unless the pin is moved deliberately.

A clean `bundle-audit` result therefore gives no assurance for Rails itself.

## Decision

Continue sourcing Rails from `rails/rails` `main` until Rails 8.2 is released, and accept the risk
that vulnerabilities in the pinned revision cannot be detected by automated advisory tooling.

- The acceptance covers the Rails dependency sourced from GitHub for the period before the 8.2
  release.
- When Rails 8.2 is released, move to the released `rails` gem from RubyGems. The acceptance ends
  at that point.
- The git-sourced `propshaft`, `flipper`, `flipper-active_record`, and `flipper-ui` share the same
  detection gap. This ADR records the gap for them but does not set their exit condition; whether
  each can move to a released gem is reviewed separately.

## Consequences

- Automated scans (`bundle-audit`, Dependabot) are not evidence that Rails is free of known
  vulnerabilities. Security reviews and evidence records must state this limit rather than report
  the dependency as clean.
- A vulnerability announced for Rails can remain unnoticed in the pinned revision for as long as
  nobody compares the announcement against the pin. This is the accepted risk.
- Moving the pin is a deliberate change. When it moves, record the old and new revisions in the
  commit message so the exposure window of any later advisory can be established.
- Revisit this decision before the 8.2 release if a critical Rails vulnerability is announced,
  or if the 8.2 release is delayed well beyond the team's expectation.
