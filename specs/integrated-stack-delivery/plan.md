# Independent acceptance follow-up

Status: current delivery accepted with explicit exceptions and follow-up backlogs.

Final result, 2026-10-13: the fresh isolated rebuild and full Minitest/Vitest suites passed; see
[A7P2](../../evidence/2026-10-13-nine-scoped-acceptance-A7P2.md) for revision-scoped results and the
exact exceptions. The prerequisite correction explicitly loads token binding-method and DBSC-status
fixtures. The historical rejection and earlier scope decisions below are superseded for this
delivery; deferred guarantees are not implemented or verified by this result.

Latest user scope, 2026-10-13: retain the ORG durable halt-audit defect in its dedicated backlog and
accept it for this delivery; defer remaining authentication/identifier verification planning to the
dedicated two-cycle backlog. Correct the passkey test's missing token-binding fixtures, then verify
the in-scope suite on a rebuilt disposable fleet. This supersedes earlier statements below that
those deferred items must block current acceptance. Historical results remain intact.

Identifier approval, 2026-10-13: the user accepted all three recommendations: narrowly scoped
database immutability triggers for APP/COM/ORG setting Preferences, no ordinary operational
exception, and investigation before proposing further tables. This supersedes the earlier
no-new-identifier-trigger hold for these three tables only. Implement reversible migrations, verify
all four bypass writers and permitted updates, rehearse down/up on the owned disposable fleet,
generate schema dumps and check drift. Preserve prior failing evidence as historical Red. The
three-setting-table correction and verification are recorded in
`evidence/2026-10-13-setting-preference-id-protection-P3V8.md`. This repairs that reproduced
identifier defect only; the historical acceptance rejection below remains open for the ORG audit
failure and other unclosed, non-waived criteria.

Subsequent user decision: accept the current Avatar implementation with follow-up investigation in
`plans/backlog/avatar-ownership-acceptance-followups.md`. Remaining Avatar-specific coverage and
transition investigation no longer block this delivery. Authentication binding/authorization
verification remains required; the ORG audit defect and identifier requirements remain open. This
supersedes Avatar-specific completion requirements below without changing historical results.

Latest acceptance decision: rejected; see `evidence/2026-10-13-nine-final-acceptance-R8D4.md`. The
setting-preference database identity boundary and ORG normal-sign-in durable halt audit have
executable failing regressions. Implementation remains incomplete. The user's
environment/policy/production exclusions are recorded in `acceptance.md` and do not waive these
failures or the remaining local coverage.

The user authorized follow-up to the 2026-10-13 independent assessment: repair OpenTelemetry
flushing, complete the missing behavioral test coverage, and exercise isolated migration/cutover and
recovery. The user accepted the observed JavaScript coverage shortfall for this delivery. The
public-ID immutability finding was a request for explanation, not authorization for a new database
enforcement mechanism. Host recreation and privacy policy remain separate decisions.

Existing acceptance IDs in `acceptance.md` and `docs/checklists/integrated-stack.md` remain the
contract. The work must distinguish absent tests from existing tests not yet mapped to a criterion.

1. Reproduce the actual development OTel flush error, correct its SDK return values, and exercise
   flush/shutdown with an in-memory exporter and no external telemetry. Preserve mail allowlists.
2. Map actual supported authentication routes, terminal/replay/phase cases, six contact models and
   Avatar transfers to executable Minitest cases. Add meaningful missing public-boundary cases;
   unsupported routes have explicit absence coverage, not invented implementations.
3. Exercise safe isolated transition and recovery paths. Verify target ownership before writes,
   preserve existing parent fleets, and record any operation that needs a new risk/recovery
   approval. Environment construction is exercised directly, never through new setup-only unit
   tests.
4. Run affected tests, both regression suites and appropriate static gates. Record remaining
   criterion-specific gaps without declaring broad acceptance from suite counts alone.

Completion requires evidence for each exercised boundary and explicit remaining dispositions.
Current execution results are recorded in `evidence/2026-10-13-nine-acceptance-follow-up-F7K2.md`:
the SDK correction and isolated recovery rehearsals passed, and 22 new behavioral tests passed in
the full 15,226-test suite. Step 2 remains open for the complete route/purpose/provider and
actor/authority coverage matrix; the evidence names the unclosed boundaries. This plan is not a
blanket acceptance declaration. No shared/production cutover, real-data purge, secret rotation, host
recreation or new identifier trigger is authorized by this follow-up. Do not modify the global test
helper or other contributors' work. Retain the scoped coverage exception without changing coverage
configuration.
