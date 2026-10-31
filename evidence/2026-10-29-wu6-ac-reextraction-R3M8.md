# WU-6 closure: AC-1..12/35 re-extraction on the run8 fleet

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; worktree carries the full WU-3..WU-5 body
  (nothing committed). The WU-0 baseline plan/inventory files:
  `plans/2026-10-28-baseline-failing-tests.md` (981 ids) and
  `plans/2026-10-28-baseline-important-test-set.md` (partition 772/1/0/3/38/168).

## Run8 as the decision run

- `bin/rails test`: 16,071 runs, 132,951 assertions, 127 failures, 124 errors, 0 skips — the final
  WU-cycle suite run recorded in `evidence/2026-10-29-wu5-cycle-closure-run8-K7D4.md`. Failing
  identifiers: 217, of which **0 are outside the baseline plan**; 764 baseline identifiers now pass.
  AC-11's reopening condition ("each WU must not make the total worse than the recorded baseline
  snapshot", counting *identifiers*, not counts) passes.
- Base suites (JavaScript): recorded earlier at `bun run test` — 96 files, 1,052 tests green.

## AC-by-AC mapping (one.md v4.2 §12 two.md ownership)

| AC | Two-unit | Observed state in the run8 worktree |
|---|---|---|
| AC-1 | WU-3 | Base com anonymous surface retained: `bin/rails routes` lists `base_com_root/revision/health(liveness/readiness/startup)/api_v0 health+revision/robots/sitemap/csp/pwa/preference screens`; no `Auth::Com`/`Visa::Com`/`Core::Com` route lines. `GET /` on the unknown com hosts gives `unknown_hosts#show` (earlier surface-scan evidence). |
| AC-2 | WU-3 | org counterpart rows mirror the com removal: `base_org_*` and `warp_org_*` surfaces attrs unchanged; `base/com/*` test files deleted; app/org ones survive with the trimmed hosts. |
| AC-3 | WU-3 | com-only behavior test removal / shared-file conversion executed (22 suites, per migration report); no skipped/placeholder substitutes; 346 retouched files by ten batch agents plus the shared sweep files. |
| AC-4 | WU-1+WU-3 | realm A (WU-1: unknown scalar refusals in `oidc_subject.rb`/`oidc_client_registry.rb` normalization) and realm B (com static client store registrations removed in WU-3; `oidc_client_registry_test.rb` expected list `core-app-jp core-org-jp warp-app-jp warp-org-jp edit-org-ww palm-app-jp tech-org-ww`) both fragment-free (2026-10-29 run8: AC contract survivors). |
| AC-5..10 | WU-3/WU-4 | one.md D-15...D-28 rows outstanding only where the base plan retained their ids after the run — the 217 baseline identifiers. |
| AC-11 | 全WU | compared over integers (981 flags at `b6e78710` vs 217 now, zero increments — the baseline criterion satisfied). |
| AC-12 | WU-3..6 | Every removed com runtime pathway is a deleted file; retained OpenAPI shapes (`bun run openapi:bundle` byte-identical earlier) and the 24 surge settings are covered by no new migrations past the WU-5 table drops. |
| AC-35 | WU-3 | Anonymous base com `GET /` response exists without sign-up/sign-in CTAs — earlier verified via `com_anonymous` surface check; `PreferenceBrowserControlsRegistry` "base"→API_V0 mapping keeps the theme/cookie endpoints reachable for the anonymous shell (per preference_registry diff). |

## Commands as evidence Identifiers

- `bin/rails routes > /tmp/routes_now.txt`; greps: `grep -icE 'visitor_|visitor\.'` → 0,
  `grep -cE 'passport|preference'` → 161, com-family names listed (base/warp com only).
- Baseline comparison script in-window: run8 217 ids vs 981 plan → 0 new.
- Surface checks: `env POSTGRESQL_TEST_PREPARE_DATABASES=$NEWLIST PARALLEL_WORKERS=1 bin/rails test test/integration/routes/{base,core,com}_*route*` → 18 runs / 317 assertions / 0 failures / 0 errors.

## Not re-verified in this pass

- The .github workflows; read-only mount persists (see 2026-10-29-wu5-cycle-closure-run8-K7D4.md).
- 4-dump drift mismatch (app_zenith, avatar, chronicle, org_zenith) predates WU-5.
