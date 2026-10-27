# OP-chain path and RuntimeRole removal (WU-18c … WU-18f)

Status: Deferred to a later cycle by owner decision D-175 (2026-10-25, "keep it simple now, improve
later"). No implementation change is authorized by this entry.
**2026-10-26:** brought back by D-181, then held until Q18-1 … Q18-4 are judged after the sign-out
implementation (see "Update (2026-10-26)").

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

## Update (2026-10-26)

The owner brought WU-18c … 18e back into the cycle (`one.md` D-181), then decided the same day that
Q18-1 … Q18-4 are judged **after the sign-out implementation is finished**. Until then WU-18c … 18e
do not start, both arms remain, and the sign-out redesign is implemented against the path each
client runs today (the OP-chain path for all twelve first-party RPs). Read-only groundwork of
2026-10-26 (details in the cycle working document `ten.md` §6b):

- **Q18-1 is larger than one page.** `VerificationBase#current_session_token` and
  `#current_actor_token` take the OP root token from `current_browser_session_security_context` for
  every browser-RP controller; Step-Up / reauthentication evidence binds to that root. Base
  controllers using the verification concerns: app 10, com 8, org 8 (identity, secrets, passkeys,
  emails, withdrawals and others). The standard arm has no security context and no root. Options:
  (a) treat Base account pages as OP-owned and keep their OP reads; (b) move every Base account
  operation to OP owner APIs with Step-Up bound to the grant; (c) switch only the nine non-Base RPs
  (Core ×3, Warp ×3, Edit, Palm, Tech) and keep the three Base RPs on the OP-chain arm until (a) or
  (b) is chosen. D-108 permits different paths for different clients.
- **Q18-2.** The withdrawal gate (`withdrawal_required` with the credential kept) exists only on the
  OP-chain arm. On the standard arm the OP token endpoint refuses refresh and exchange for an actor
  whose `active?` is false (`OidcTokenExchangeCoordinator`). Withdrawal pages are Base pages, so the
  answer follows Q18-1.
- **Q18-3.** `*OidcIdentityBinding` and `Core*Bridge` are used only by the OP-chain callbacks and
  `OidcRpIdentityProvisioning`. `ClientIdentity`, `VisitorIdentity` and `OperatorIdentity` are also
  read and written by persona, avatar and inventory code; whether those features still get an
  identity row once the callback stops provisioning must be checked feature by feature.
- **Q18-4.** The `rp_*` stores have no place for the ID Token the RP must send as `id_token_hint`
  (`one.md` D-184); a migration per RP database is needed. `rp_op_session_bindings.revoked_at` and
  `rp_principals.disabled_at` give NULL a meaning (live / enabled), contrary to AGENTS.md; fix them
  before these tables carry live sessions.
