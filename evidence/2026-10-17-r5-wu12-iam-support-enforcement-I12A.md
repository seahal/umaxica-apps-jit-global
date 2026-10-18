# R5-WU12 IAM, Support and Enforcement authorities

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree. Pattern
approved by the user with the Avatar contract (2026-10-17).

- IAM (org): `/api/v0/iam/grants` list/show, grant screen, issue, revoke. Owner re-checks Step-Up
  under the root lock; `OrgAdministrativeAudit` now takes its browser facts from an overridable
  `audit_request` (the owner uses the request id/IP/User-Agent forwarded by the authenticated RP).
- Support (org over app/com): `/api/v0/support/:realm/accounts` list/show, revocation screen, revoke
  (AccountSessionRevocation + audit), revocation result. The confirmation page's live session count
  now comes from the owner.
- Enforcement (org over app/com/org): `/api/v0/support/:realm/enforcement_cases` (index/show/new/
  create, approval, release, appeal review) — the existing controllers moved to the owner verbatim
  with `OwnerPageResponses` (page → `{component, props}`, redirect → `{redirect}`, Step-Up at the
  owner); the Base Self-RP pages relay through `OrgOwnerPageRelay`, forwarding format, params and
  URL context, and pass JSON answers through with the owner's exact status (e.g. 202).
- Account standing (app/com/org `/identity/standing`): same owner-page relay.
- Deviation (recorded): for the Enforcement console and standing pages, page props are composed at
  the owner (same application, same i18n/routes) to keep behavior exact; templates stay RP-side.
- Classification: Base identity recovery/appeal pages run inside the recovery ceremony (Auth/OP
  limited owner contract per one.md 7.5), not as ordinary RP access; they are not relayed.
- Results: IAM 16, Support 33, Enforcement + identity read-only pages 91, standing slices 71 runs —
  all 0 failures.
