# Preference legacy transport audit

- Date: 2026-09-22
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing local modifications were present; this audit made no source, test,
  route, database, or external-service change.

## Finding

The legacy `/web/v0` preference transport cannot be removed or renamed safely as a local route
cleanup. The current repository has live browser callers for the non-Core preference contract:

- `src/controllers/cookie_banner_controller.ts` requests `/web/v0/cookie`;
- `src/controllers/cookie_toggle_controller.ts` requests `/web/v0/cookie`;
- `src/lib/theme.ts` requests `/web/v0/theme`.

The current route definitions and the preference behavior contract intentionally keep these
non-Core endpoints while Core exposes its canonical `/api/v0/preferences/cookie` and
`/api/v0/preferences/theme` endpoints. The route comments require a compatibility review that
identifies every caller and assigns the replacement API owner before migration.

## Disposition

This is `NEXT_CYCLE / CONTRACT_UNDEFINED`, not a defect to fix by changing the route namespace.
The safe follow-up must first define the replacement contract, migrate every direct caller, cover
CSRF/no-store/cookie and surface isolation behavior, and only then retire the legacy route. No
new API or compatibility alias was added in this audit.

## Evidence

Relevant current files:

- `config/routes/base.rb`
- `config/routes/side.rb`
- `src/controllers/cookie_banner_controller.ts`
- `src/controllers/cookie_toggle_controller.ts`
- `src/lib/theme.ts`
- `docs/architecture/preference-behavior-contract.md`
- `adr/api-route-vocabulary-consolidation.md`

No external service was contacted or changed.
