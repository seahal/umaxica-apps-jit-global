# Security Checklist

## Contents

- OWASP Top 10 quick reference
- Pre-commit verification
- Security review checklist (authentication, authorization, input, data, infrastructure, supply
  chain, AI/LLM)
- Incident response for a leaked secret

## OWASP Top 10 quick reference

Ordering follows the OWASP Top 10 (2021 edition). The prevention patterns for each live in
`SKILL.md`; this table is for looking up which category a finding belongs to.

| ID  | Category                                   | Prevention in one line                                              |
| --- | ------------------------------------------ | ------------------------------------------------------------------- |
| A01 | Broken Access Control                      | Check ownership on every resource, not just authentication          |
| A02 | Cryptographic Failures                     | HTTPS everywhere, argon2/bcrypt/scrypt for passwords, no plaintext  |
| A03 | Injection                                  | Parameterize queries, escape output, never concatenate input        |
| A04 | Insecure Design                            | Threat model before building; write abuse cases beside use cases    |
| A05 | Security Misconfiguration                  | Security headers, restrictive CORS, no stack traces to users        |
| A06 | Vulnerable and Outdated Components         | Audit dependencies, commit the lockfile, review new packages        |
| A07 | Identification and Authentication Failures | Rate-limit auth, expire reset tokens, httpOnly/secure/sameSite      |
| A08 | Software and Data Integrity Failures       | Verify signatures, pin versions, distrust untrusted deserialization |
| A09 | Security Logging and Monitoring Failures   | Log security events as data; alert on auth anomalies                |
| A10 | Server-Side Request Forgery                | Allowlist host and scheme, reject private IPs, forbid redirects     |

## Pre-commit verification

```bash
# Staged changes contain no obvious secret material
git diff --cached | grep -iE "password|secret|api[_-]?key|token|BEGIN [A-Z ]*PRIVATE KEY"

# Dependencies have no known critical or high vulnerabilities
npm audit --audit-level=high

# .gitignore covers secret files
grep -qE '^\.env$' .gitignore && grep -qE '^\*\.key$' .gitignore
```

A hit on the first command is not automatically a leak — variable names and test fixtures match it
too. Read each hit before deciding.

## Security review checklist

### Authentication

- [ ] Passwords hashed with bcrypt, scrypt, or argon2 (bcrypt salt rounds ≥ 12)
- [ ] Session tokens are httpOnly, secure, and sameSite
- [ ] Login has rate limiting
- [ ] Password reset tokens expire

### Authorization

- [ ] Every endpoint checks user permissions, not just authentication
- [ ] Users can only access resources they own
- [ ] Admin actions verify the admin role server-side

### Input

- [ ] All external input validated at the system boundary
- [ ] Database queries parameterized
- [ ] HTML output encoded or escaped by the framework, with no bypass
- [ ] Server-side URL fetches restricted to an allowlist
- [ ] File uploads restricted by type and size, with magic-byte checks where it matters

### Data

- [ ] No secrets in source code or version control
- [ ] Sensitive fields excluded from API responses
- [ ] PII encrypted at rest where applicable

### Infrastructure

- [ ] Security headers configured (CSP, HSTS, X-Frame-Options, X-Content-Type-Options)
- [ ] CORS restricted to known origins, never wildcard with credentials
- [ ] Error responses expose no internal detail or stack traces
- [ ] Rate limiting active on authentication endpoints

### Supply chain

- [ ] Lockfile committed; CI installs with `npm ci` rather than `npm install`
- [ ] New dependencies reviewed for maintenance, download counts, and postinstall scripts
- [ ] Package names checked against common typosquats

### AI and LLM features

- [ ] Model output treated as untrusted — never passed to eval, SQL, a shell, `innerHTML`, or a file
      path without validation
- [ ] Secrets and other users' data kept out of prompts
- [ ] Tool and agent permissions scoped; destructive actions require confirmation
- [ ] Token, request-rate, and recursion-depth caps in place
- [ ] Retrieval data partitioned per tenant; indexed documents validated

## Incident response for a leaked secret

A secret that has reached a remote is compromised, regardless of whether the commit was later
amended or the history rewritten.

1. Revoke and reissue the credential at its source before touching the repository.
2. Update the running configuration with the new value and confirm the service is healthy.
3. Purge the value from history, and treat that as cleanup rather than remediation.
4. Check access logs for use of the old credential between the leak and the revocation.
