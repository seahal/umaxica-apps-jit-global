# Security Policy

## Supported Versions

Only the latest code on the `main` branch is supported. Security fixes land on `main` and ship as
part of normal updates.

The `develop` branch and any other branch are development state and receive no security support. No
long-term support branches are maintained, and no separate security release numbering exists.

## Reporting a Vulnerability

Report privately through GitHub Security Advisories:

- https://github.com/seahal/umaxica-app-jit/security/advisories/new

This is the only reporting channel. Do not open a public issue, discussion, or pull request for a
suspected vulnerability.

Please include:

- a clear description of the issue and its security impact,
- the affected commit or version,
- reproduction steps, and a minimal proof of concept if you have one,
- relevant configuration details.

Do not include secrets in your report. Redact tokens, session cookies, authorization headers, and
any personal data belonging to real users; describe what you obtained instead of pasting it.

## Response Expectations

- Acknowledgement within 3 business days.
- Initial triage update within 7 business days.
- For valid issues, we develop a fix and coordinate disclosure. Depending on complexity and
  coordination needs, remediation may take up to 90 days.

This project is maintained by a small team. These are the timelines we commit to, not a
severity-tiered service level agreement.

There is no bug bounty program; we do not offer monetary rewards.

## Scope

In scope:

- Vulnerabilities in this repository's code and its default configuration.
- Issues exploitable without special privileges, or that enable privilege escalation, sensitive data
  exposure, or remote code execution.
- Leakage across the three trust boundaries this application maintains — `app` (end users), `org`
  (staff and organization), and `com` (public and corporate). Any path that lets state, session
  identity, or data cross between these surfaces is a security defect and is high impact.
- Missing or bypassable authentication, authorization, verification, CSRF, or rate-limit
  protections.

Out of scope:

- Unauthorized testing against production hosts, including `www.umaxica.app` and `umaxica.com`. Test
  locally or against a deployment you control.
- Vulnerabilities in third-party services or in dependencies not maintained here. Report those
  upstream; you may link the upstream report in an advisory here so we can track impact.
- Best-practice suggestions without demonstrable security impact.
- Denial of service through excessive resource consumption, rate-limit bypasses that require
  unrealistic request volumes, and social engineering of maintainers.

## Safe Harbor

We support good-faith research. If you:

- make a good-faith effort to avoid privacy violations, destruction of data, and interruption or
  degradation of our services, and
- test only against local environments or deployments you control,

then we will not pursue legal action. If you are unsure whether your testing qualifies, ask first
through a private advisory.

## Disclosure and Credit

We prefer coordinated disclosure. Reporters are credited in release notes unless they ask otherwise.
When appropriate we request a CVE and include references in the published security advisory.

## Dependencies

Dependency and code scanning run in CI: Dependabot, Brakeman, bundler-audit, `bun audit`, CodeQL,
and Gitleaks. Findings from these tools are handled through the normal update process rather than
the advisory channel.

## Questions

For non-sensitive security questions, open a regular issue. For anything that could describe an
exploitable weakness, use the private advisory link above.

Thank you for helping keep users safe.
