# OP/RP Ownership Manifest (R5-WU01)

Status: generated 2026-10-17 from the development boot (eager-loaded models, live development
catalog, controller source). It is the evidence base for which store each RP cell may touch after R5
and which current reads must move behind an OP or domain HTTPS contract. Regenerate it, do not
hand-edit counts, when models or controllers change.

Owner specification: `one.md` sections 4, 5.3 and R5-WU01.

## Model inventory by connection

887 concrete models resolved to 32 connections. Owner is the target owner from `one.md` 5.3.

| Connection                                                                                                     | Models        | Target owner                                                                               | RP cell access after R5                 |
| -------------------------------------------------------------------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------------ | --------------------------------------- |
| `op_base_app` / `op_base_com` / `op_base_org`                                                                  | 50 / 37 / 38  | OP of that realm (root, Code, Grant, Refresh, logout, consumed JTI)                        | None; only via public OP HTTPS/JWKS     |
| `app_zenith` / `com_zenith` / `org_zenith`                                                                     | 109 / 93 / 94 | Zenith realm authority (identity, credentials, org graph, enforcement, capability grants)  | None; domain HTTPS only                 |
| `rp_<family>_<realm>` (12 cells)                                                                               | 7 each        | That RP cell (principal, identity binding, session, callback, attempt, receipt, tombstone) | Own cell only                           |
| `publishing`                                                                                                   | 157           | Publishing domain authority                                                                | None; Publishing HTTPS (R5-WU13)        |
| `avatar`                                                                                                       | 46            | Avatar domain authority                                                                    | None; Avatar HTTPS (R5-WU14)            |
| `app_setting` / `com_setting` / `org_setting`                                                                  | 27 each       | Existing preference owners (unchanged)                                                     | Unchanged by R5                         |
| `app_signal` / `com_signal` / `org_signal`, `chronicle`, `occurrence`, `queue`, `primary`, `search`, `storage` | —             | Existing owners (unchanged)                                                                | Unchanged; queue isolation per R5-WU03A |

## Tables without a model

These exist in the development catalog with no model class. No application code reads them through
Active Record, so no RP cell depends on them. They stay with their current store; removal, if any,
is a separate decision.

| Connection   | Unmodeled tables | Examples                                                            |
| ------------ | ---------------- | ------------------------------------------------------------------- |
| `app_zenith` | 13               | `accounts`, `apple_auths`, `roles`, `legacy_replaced_clients`       |
| `org_zenith` | 13               | `staff_identity_statuses`, `workspace_statuses`, `role_assignments` |
| `chronicle`  | 36               | `app_document_audit_events`, `com_document_behaviors`               |
| `avatar`     | 12               | `posts`, `post_versions`, `client_avatar_extractions`               |

## Current direct reads by RP code (work list)

Constants referenced directly from RP controller trees and the shared RP Concerns. Every entry below
is a cross-owner read that R5 must replace; none may survive cell activation (R5-WU19).

| RP code                   | OP stores read                                           | Zenith stores read                                                                | Domain stores read                | Replaced by                                        |
| ------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------- | --------------------------------- | -------------------------------------------------- |
| `app/controllers/core/**` | `ClientToken`, `VisitorToken`, `OperatorToken`           | `Client`/`Visitor`/`Operator`, `*Identity`, `*OidcIdentityBinding`, `Core*Bridge` | —                                 | R5-WU07 local session; R5-WU12/15 domain contracts |
| `app/controllers/warp/**` | —                                                        | `Client`/`Visitor`/`Operator`, `*Identity`, `*OidcIdentityBinding`                | —                                 | R5-WU07                                            |
| `app/controllers/palm/**` | —                                                        | `Client`, `ClientIdentity`, `ClientOidcIdentityBinding`                           | —                                 | R5-WU07                                            |
| `app/controllers/edit/**` | —                                                        | `Operator`, `OperatorIdentity`, `OperatorOidcIdentityBinding`                     | 12 `Publishing::*::Entry` classes | R5-WU07; R5-WU13 Publishing HTTPS                  |
| `app/controllers/tech/**` | `OpOrgGrant`, `OperatorToken`                            | `Operator`, `OperatorIdentity`, `OperatorOidcIdentityBinding`                     | —                                 | R5-WU07; R5-WU11 capability HTTPS                  |
| `BrowserRpAuthentication` | `ClientToken`/`VisitorToken`/`OperatorToken`, `Op*Grant` | `Client`, `Visitor`, `Operator`                                                   | —                                 | R5-WU07 (local session + Access JWT)               |
| `OidcCallback`            | —                                                        | `Client`                                                                          | —                                 | R5-WU07 callback into local principal              |
| `AuthenticationJwtTokens` | `*DeviceSession`, `*Token`                               | —                                                                                 | —                                 | OP-only issuance (R5-WU04)                         |

Indirect reads through services, operations and policies are not expanded here; each downstream
packet confirms its own consumers before changing them and reports any UNKNOWN as a stop.

## Contract checks

- Successor sign-out ADR
  `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md` (Accepted
  2026-10-16) is the design R5-WU09/10 implement; no amendment is required by this inventory.
- Status 103 (retired Restricted) was cleaned up in R2; this inventory found no Restricted API
  replacement.
