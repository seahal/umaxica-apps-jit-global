# Brakeman findings remediation

Status: closed

The user authorized investigation and resolution of all 63 findings from `bin/brakeman -A` on
2026-10-20. This change preserves surface ownership, authentication, authorization, locks, failure
behavior and existing data. It adds no warning suppressions or scanner exclusions.

- AC-1: All twelve Publishing targets resolve through explicit class references; unknown targets are
  refused, and caller authentication and Publishing policy checks remain in place.
- AC-2: GET and HEAD relay reads through GET; POST remains a write request.
- AC-3: The Avatar group HTTP lookup has an unambiguous name and continues escaping path input.
- AC-4: Owner lookups query the declared association scope without cached singular targets. Existing
  missing-record exceptions and nullable lookup results retain their respective behavior.
  Current-root-token lookups retain both token ID and device-session scope; receipt validation
  retains its token-to-principal comparison.
- AC-5: Test catalog inspection uses the Rails-configured local credential, preserving fixed host,
  port, username and test-database safety checks. No credential is printed or introduced.
- AC-6: Brakeman completes with zero errors and zero warnings at all confidence levels.

Verification uses the nearest affected public tests, targeted regression coverage and the scanner.
Database preparation must pass the existing catalog guards; pending migrations are checked before
running tests. Runtime acceptance stays open if relevant tests cannot run.

Implementation rationale: fixed-name association scopes express the existing ownership relation.
Resetting the scope before an explicit query avoids reusing cached principals or foreign-key
predicates, without changing the owner record's unsaved attributes. Explicit `take!` / `take`
preserves strict / nullable lookup behavior. Ordinary association readers can reuse cached owners;
`reload_<association>` is also unsuitable here because it triggers the application's strict-loading
guard. Neither strict loading nor its error handling is relaxed. Converting `find` to `find_by`, or
changing only the spelling of a global query, would not preserve the contract.

## Acceptance disposition

The [verification record](../../evidence/2026-10-20-brakeman-remediation-B6K2.md) accounts for all
63 original findings and records the successful targeted run: 251 tests, 1,566 assertions.

| Acceptance | Verification                                                                                                                       | Disposition                                    |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| AC-1       | Publishing EntriesController tests: twelve cells, route rejection, caller refusal and suspended-operator refusal                   | Passed                                         |
| AC-2       | BaseOrgSupportRelayTest public action orchestration; BrowserRpAuthenticationTest request coverage                                  | Passed within the stated unit/request coverage |
| AC-3       | DomainAuthorityProtocolTest escaping and owner refusals; GroupsControllerTest                                                      | Passed                                         |
| AC-4       | Owner, purge, receipt, OTP, admission, passkey and session-boundary tests listed in the record; source review of all finding sites | Passed targeted scope                          |
| AC-5       | Test catalog inspection and guarded test preparation using the Rails credential                                                    | Passed                                         |
| AC-6       | Brakeman with every check and confidence level, no suppressions                                                                    | Zero warnings and errors                       |

Current query mechanics are documented in
[owner record lookups](../../docs/security/owner-record-lookups.md). The durable HEAD relay
requirement is AUTHZ-6 in [authorization](../../docs/checklists/authorization.md). The complete
Rails suite, concurrency suites and production deployment were outside this local verification; this
closure does not claim those checks or a deployment.
