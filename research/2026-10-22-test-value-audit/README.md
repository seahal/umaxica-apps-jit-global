# Test value audit — 2026-10-22

A complete source-definition inventory and structural screen, with **39 substantive findings affecting 110 definitions**: **37 confirmed finding groups affecting 59 definitions**, plus **2 candidate families affecting 51 definitions**. The confirmed groups include nine same-owner duplicate scenarios, misleading claims, weak or vacuous oracles, production-path drift and explicit suite-ownership policy conflicts.

**Coverage limit:** this is not a completed semantic approval/rejection of every test. Every definition has a ledger entry, its declared protection, assertion excerpts, static production-source candidates, duplicate membership and review state. Only named findings and stated retention decisions were investigated semantically. Entries marked **S** or **G** still require individual semantic review. Static target links are not runtime call traces; a green suite does not establish mutation adequacy. No test deletion or production/test-infrastructure change was performed.

## Start here

- [Findings and proposed dispositions](findings.md): each has its intended protection, exact test definitions, implementing sources, concrete weakness, replacement/retention condition and next action.
- [Duplicate groups](duplicates.md): all 107 token-identical groups, 375 member definitions, with contexts kept separate.
- [Harness and production-path interpretation](harness.md): shared authentication, forgery, flag, fixture, provider, storage and browser-test seams; explicit retention decisions and policy conflicts.
- [Execution observations](execution.md): complete run outcomes and all 61 unsuccessful Rails outcomes, independent of value judgments.
- [Structural signals and remaining queue](signals.md): every flagged definition, including false-positive cautions.
- [All source files and hashes](files.md): 2779 files, including fixtures/support, two comment-only historical markers and the test-provider adapter that is not a test suite.

## Revision and scope

- Commit: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`.
- The worktree already contained uncommitted changes in production code, tests, configuration and accepted/current documents. The audit uses their current contents, not a clean checkout. No change attribution to an individual existing diff is claimed.
- 2489 test/spec-suffixed files: 2,376 Ruby files and 113 JavaScript/TypeScript files. 2486 contain runnable-source definitions; three contain none (two comment-only markers and `OutboundSmsProvidersTest`, a provider adapter).
- **14,756 source definitions:** 13,659 Minitest definitions, 1,064 Vitest definitions and 33 Playwright definitions. Source counts differ from runtime counts because loops and each tables expand cases. Nine private helpers/controller actions named `test_*` were explicitly excluded.
- Discovery: `git ls-files --cached --others --exclude-standard -z`, filtered to `test/`, `gait/`, `e2e/` and `*_test.rb` / `*.test.*` / `*.spec.*` source suffixes. Ignored build/generated files and installed dependencies are outside this repository-source audit.
- Scope digest: `174b5de48dd6b5041cf1d9f67c6bf5e4652e3ebbfae0e6147057640b7268869b`. The [manifest](files.md) records every file hash so pre-existing dirty contents remain identifiable.
- Ruby declarations were parsed with Prism 1.8.1 under Ruby 4.0.7. JS/TS declarations were parsed with the installed Babel parser and TypeScript/JSX plugins. No source parse failures were observed. A separate Prism parse indexed 3,349 production Ruby files. No production file was loaded merely to build the static inventory.

## Review states

| State | Meaning | Retirement authority |
| --- | --- | --- |
| LV confirmed / confirmed-duplicate | The documented weak oracle, duplicate or misleading claim was checked against the linked code. | Proposed action only; satisfy the replacement and security-boundary conditions first. |
| LV confirmed-policy-conflict | Current test subject conflicts with the accepted no-environment-tests ownership policy. | Preserve the intent and replace setup assurance with actual observed evidence before any retirement. |
| LV candidate | A concrete risk family needing a per-subject contract decision. | No deletion conclusion. The 50 integer-ID definitions are expressly a candidate family. |
| R | A stated retention reason was checked for the indicated example. | Preserve the stated contract; this is not a claim that every assertion in the file is necessary. |
| G | A repository-mandated security guard. | Preserve it; a signal cannot override the explicit regression-guard contract. Individual semantic audit remains open unless separately stated. |
| S | Source inventory and structural screening completed; individual semantic review remains open. | No quality approval and no deletion conclusion. |

P1/P2/P3 in the findings are work ordering, not exploit severities. Filenames mentioning coverage, stubs, shared setup and source assertions are neither necessary nor sufficient reasons to retire a test. Constants describing persisted IDs, ORM/database restriction boundaries and separate surface/policy owners require special care.

## Method and important limits

For every definition, the inventory records the declared claim, owner, assertion excerpts, source range, possible production target and observable request expressions. All files are hash-pinned. Oracle excerpts may quote existing localized customer strings; these are source/localization quotations, not newly authored non-English repository prose. Whole-body token hashes identify exact-body candidates while preserving literals and identifiers. Surrounding setup, imports, actor type, surface and loop parameters are excluded from that hash, so body equality alone is never a redundancy decision. Similar-but-not-identical scenarios are not exhaustively proved equivalent by this technique.

The substantive review followed the highest-risk false-confidence signals and same-owner duplicate groups, compared tests with actual implementing code, read the relevant ADR/rules/docs, ran the full Minitest and Vitest suites, and used a narrowly scoped in-memory mutation as a concrete counterexample. Assertion excerpts and source matches are aids to further review, not replacements for following the public execution path. The ledger deliberately leaves unresolved items open instead of treating mechanically extracted test names as verified behavior.

The remaining semantic work is explicit: inspect all S/G entries against their public call paths, fixture/setup predicates and owning contract; compare cross-file behavioral overlap beyond token equality; verify all cutoff/sentinel and authorization partitions; establish per-test mutation adequacy where risk warrants; and run browser suites with their required runners. This snapshot does not claim those steps are complete.

## Verification outcome

- Vitest: **100 files / 1,160 tests passed**.
- Full Rails: **18,421 runs / 159,883 assertions / 60 failures / 1 error / 0 skips**, seed 55776.
- Focused ordinary Rails run: **13 runs / 37 assertions / no failures, errors or skips**.
- Deliberately broken process-local methods: **one expected failure in the genuine Health test; five suspect tests stayed green**. No repository source mutation was made.
- Browser E2E: **not run**.

The working tree's full Rails suite is not green. Its failures are listed separately and were not repaired or relabeled low value. See [evidence](../../evidence/2026-10-22-test-value-audit-Q7M4.md) for the revision-scoped record.

## Inventory by area

| Inventory | Source definitions |
| --- | --- |
| [e2e](inventory/e2e.md) | 33 |
| [gait](inventory/gait.md) | 1064 |
| [rails-adapters](inventory/rails-adapters.md) | 126 |
| [rails-concerns](inventory/rails-concerns.md) | 24 |
| [rails-concurrency](inventory/rails-concurrency.md) | 2 |
| [rails-config](inventory/rails-config.md) | 27 |
| [rails-consumers](inventory/rails-consumers.md) | 72 |
| [rails-contracts](inventory/rails-contracts.md) | 92 |
| [rails-controllers-auth](inventory/rails-controllers-auth.md) | 988 |
| [rails-controllers-base](inventory/rails-controllers-base.md) | 1038 |
| [rails-controllers-concerns](inventory/rails-controllers-concerns.md) | 702 |
| [rails-controllers-core](inventory/rails-controllers-core.md) | 42 |
| [rails-controllers-edit](inventory/rails-controllers-edit.md) | 48 |
| [rails-controllers-palm](inventory/rails-controllers-palm.md) | 14 |
| [rails-controllers-root](inventory/rails-controllers-root.md) | 116 |
| [rails-controllers-security](inventory/rails-controllers-security.md) | 1 |
| [rails-controllers-tech](inventory/rails-controllers-tech.md) | 24 |
| [rails-controllers-warp](inventory/rails-controllers-warp.md) | 64 |
| [rails-errors](inventory/rails-errors.md) | 91 |
| [rails-forms](inventory/rails-forms.md) | 22 |
| [rails-helpers](inventory/rails-helpers.md) | 51 |
| [rails-initializers](inventory/rails-initializers.md) | 47 |
| [rails-integration](inventory/rails-integration.md) | 1356 |
| [rails-jobs](inventory/rails-jobs.md) | 158 |
| [rails-lib](inventory/rails-lib.md) | 303 |
| [rails-mailers](inventory/rails-mailers.md) | 30 |
| [rails-middleware](inventory/rails-middleware.md) | 9 |
| [rails-migrations](inventory/rails-migrations.md) | 2 |
| [rails-models-a](inventory/rails-models-a.md) | 627 |
| [rails-models-b](inventory/rails-models-b.md) | 10 |
| [rails-models-c](inventory/rails-models-c.md) | 785 |
| [rails-models-concerns](inventory/rails-models-concerns.md) | 405 |
| [rails-models-d](inventory/rails-models-d.md) | 63 |
| [rails-models-e](inventory/rails-models-e.md) | 100 |
| [rails-models-f](inventory/rails-models-f.md) | 2 |
| [rails-models-g](inventory/rails-models-g.md) | 1 |
| [rails-models-h](inventory/rails-models-h.md) | 16 |
| [rails-models-i](inventory/rails-models-i.md) | 59 |
| [rails-models-j](inventory/rails-models-j.md) | 16 |
| [rails-models-l](inventory/rails-models-l.md) | 19 |
| [rails-models-m](inventory/rails-models-m.md) | 42 |
| [rails-models-n](inventory/rails-models-n.md) | 2 |
| [rails-models-o](inventory/rails-models-o.md) | 723 |
| [rails-models-p](inventory/rails-models-p.md) | 141 |
| [rails-models-publishing](inventory/rails-models-publishing.md) | 222 |
| [rails-models-r](inventory/rails-models-r.md) | 123 |
| [rails-models-s](inventory/rails-models-s.md) | 143 |
| [rails-models-t](inventory/rails-models-t.md) | 59 |
| [rails-models-v](inventory/rails-models-v.md) | 235 |
| [rails-models-w](inventory/rails-models-w.md) | 17 |
| [rails-models-z](inventory/rails-models-z.md) | 16 |
| [rails-notifiers](inventory/rails-notifiers.md) | 14 |
| [rails-operations](inventory/rails-operations.md) | 725 |
| [rails-policies](inventory/rails-policies.md) | 581 |
| [rails-presenters](inventory/rails-presenters.md) | 68 |
| [rails-queries](inventory/rails-queries.md) | 74 |
| [rails-resolvers](inventory/rails-resolvers.md) | 71 |
| [rails-security](inventory/rails-security.md) | 152 |
| [rails-serializers](inventory/rails-serializers.md) | 9 |
| [rails-services-acme](inventory/rails-services-acme.md) | 14 |
| [rails-services-avatar_backfill](inventory/rails-services-avatar_backfill.md) | 18 |
| [rails-services-avatar_lifecycle](inventory/rails-services-avatar_lifecycle.md) | 9 |
| [rails-services-avatar_provisioning](inventory/rails-services-avatar_provisioning.md) | 7 |
| [rails-services-avatar_social_graph](inventory/rails-services-avatar_social_graph.md) | 29 |
| [rails-services-dbsc](inventory/rails-services-dbsc.md) | 35 |
| [rails-services-dpop](inventory/rails-services-dpop.md) | 14 |
| [rails-services-identity](inventory/rails-services-identity.md) | 104 |
| [rails-services-jump_rt](inventory/rails-services-jump_rt.md) | 117 |
| [rails-services-oidc](inventory/rails-services-oidc.md) | 241 |
| [rails-services-org](inventory/rails-services-org.md) | 47 |
| [rails-services-outbound](inventory/rails-services-outbound.md) | 15 |
| [rails-services-redirects](inventory/rails-services-redirects.md) | 7 |
| [rails-services-request_context](inventory/rails-services-request_context.md) | 6 |
| [rails-services-retention](inventory/rails-services-retention.md) | 3 |
| [rails-services-root](inventory/rails-services-root.md) | 851 |
| [rails-services-security](inventory/rails-services-security.md) | 6 |
| [rails-services-sign](inventory/rails-services-sign.md) | 64 |
| [rails-services-sign_in](inventory/rails-services-sign_in.md) | 49 |
| [rails-services-sign_up](inventory/rails-services-sign_up.md) | 50 |
| [rails-services-staff_secret_credentials](inventory/rails-services-staff_secret_credentials.md) | 12 |
| [rails-services-step_up](inventory/rails-services-step_up.md) | 49 |
| [rails-services-valkey](inventory/rails-services-valkey.md) | 40 |
| [rails-services-webauthn](inventory/rails-services-webauthn.md) | 9 |
| [rails-subscribers](inventory/rails-subscribers.md) | 39 |
| [rails-support](inventory/rails-support.md) | 5 |
| [rails-tasks](inventory/rails-tasks.md) | 14 |
| [rails-tooling](inventory/rails-tooling.md) | 63 |
| [rails-unit](inventory/rails-unit.md) | 470 |
| [rails-validators](inventory/rails-validators.md) | 4 |
| [rails-values](inventory/rails-values.md) | 284 |
| [rails-views](inventory/rails-views.md) | 15 |

## Governing sources

The audit follows [AGENTS.md](../../AGENTS.md), the [testing rule](../../.agents/harnesses/rules/generic/testing.mdc), [no test-only code](../../.agents/harnesses/rules/generic/no-test-only-code.mdc), [static invariant guards](../../.agents/harnesses/rules/project/static-invariant-guards.mdc), [no-environment-tests](../../.agents/harnesses/rules/project/no-environment-tests.mdc), [the accepted environment-testing ADR](../../adr/no-test-suite-for-environment-construction.md), [the CSRF test-environment ADR](../../adr/csrf-protection-disabled-in-test-environment.md) and [repository knowledge ownership](../../docs/reference/repository-knowledge-architecture.md). Research remains non-normative; no proposed test retirement changes those contracts.
