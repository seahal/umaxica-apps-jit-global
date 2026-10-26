# OP-chain path and RuntimeRole removal (WU-18c … WU-18f)

Status: Deferred to a later cycle by owner decision D-175 (2026-10-25, "keep it simple now, improve
later"). No implementation change is authorized by this entry.

## Scope deferred

From the 2026-10 authentication cycle (`two.md`, "WU-18 sub-units"; contract D-108):

- **WU-18c / 18d / 18e:** remove the pre-R5 OP-chain arm and RuntimeRole per resource type (app,
  then com, then org including Tech) in `OidcCallback`, `BrowserRpAuthentication`,
  `CoreBrowserApiBoundary`, `OidcRpLogoutLauncher` and the RP tests; after the last surface, delete
  `rp_cell_process?`, `RuntimeRole`, the route guard, the key-isolation branches,
  `UMAXICA_RUNTIME_ROLE` / `UMAXICA_RP_BROWSER_ADMISSION` and the test role helpers.
- **WU-18f:** drop the OP-chain-only RP-identity tables (destructive; needs counts and a recovery
  plan at the time).

## What stays as written

- WU-18a inventory and WU-18b per-RP switch plan in `two.md` (static reading of 2026-10-25 on
  `bde2346c1` plus the uncommitted worktree). Re-verify both against the code before starting: the
  inventory is a snapshot.
- Prerequisites recorded there: WU-02, WU-10 and WU-11; standard-RP tests green before each removal.

## Open questions (must be answered before 18b can be accepted)

- **Q18-1 (blocking, Base surfaces).** The OP-chain arm gives Base RP pages the canonical actor,
  root token and `BrowserSessionSecurityContext`; the standard arm gives the cell principal and no
  security context. Do those pages read OP owner APIs over HTTPS, or are they OP-owned and therefore
  not RP pages?
- **Q18-2.** The withdrawal gate has no standard-arm equivalent: should the OP refuse token issuance
  and refresh for a deactivated actor, or must the RP read actor status from an owner API?
- **Q18-3.** `OidcRpIdentityProvisioning` and the `Core*Bridge` rows disappear with the arm; confirm
  no RP feature needs them after the switch.
- **Q18-4.** WU-18f drop list: only the RP-identity tables of 18a? The `op_*_grants`
  `oidc_sid`/`oidc_client_id` columns and `op_*_grant_logout_hints` are written by the OP-chain
  callback today and read as the WU-14 `id_token_hint`; the standard arm must store its own hint
  first.

## Consequence of the deferral

Both arms remain: a client still runs on exactly one of them (never two authorities for one client,
D-108), RuntimeRole stays, and no table is dropped in this cycle.
