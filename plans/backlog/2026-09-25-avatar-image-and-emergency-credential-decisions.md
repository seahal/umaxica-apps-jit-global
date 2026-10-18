# Decision proposals: Dashboard Avatar image and Emergency Credential acknowledgement

Status: decided 2026-09-26. The owner approved option A for both sections. Decisions are recorded in
`adr/base-dashboard-avatar-image-delivery.md` and
`adr/emergency-secret-credential-commit-acknowledgement.md`; remaining work is tracked in
`plans/backlog/2026-09-26-integrated-auth-remaining-ledger.md`. The text below is the original proposal.

Two acceptance gates in `plans/backlog/2026-09-24-integrated-auth-avatar-warp-plan.md` stay open
because they need a contract decision rather than more code. This note states the observed facts and
the options, with a recommendation for each.

## 1. Base Dashboard Avatar image delivery (Phase 8, item 6)

### Observed facts

- `Avatar` stores its image through Shrine (`AvatarImageUploader`, boundary `:avatar`, JPEG/PNG/WebP/GIF,
  5 MiB). Metadata lives in `avatars.image_data`.
- `ObjectStorage::ShrineConfiguration` resolves the avatar boundary to a private S3-compatible bucket
  in development/staging and AWS S3 in production; tests use memory storage.
- No route, controller, or helper currently serves an Avatar image, and no presigned-URL helper
  exists in `app/`.
- Avatar capability is asymmetric: app requires an Avatar, org's is optional, com has none.

### Options

| Option | Description | Trade-offs |
| --- | --- | --- |
| A. Authenticated Rails proxy route | `GET /dashboard/avatar_image` per surface streams the selected Avatar's stored file after the normal authenticated/selected-actor checks | Keeps the bucket private and the surface boundary server-side. Costs app bandwidth; needs `Cache-Control: private` and an ETag. |
| B. Short-lived presigned URL | Dashboard renders a presigned GET URL (for example 5 minutes) generated server-side for the selected Avatar | Lower app load. The URL works for anyone who holds it until expiry and it leaks into browser history and logs; CSP `img-src` must allow the bucket host. |
| C. Public derivative bucket | Copy a resized derivative to a public/CDN path | Simplest delivery, but Avatar images become world-readable by URL, contradicting the private boundary. |

Absence contract (needed for every option):

- app: an active binding without an image renders a fixed, static, non-identifying default image
  served from the asset pipeline. A missing active binding stays an invariant failure, as the plan
  already requires.
- org: no selected Avatar means no image element, with the Persona moniker only.
- com: no image element, since com has no Avatar capability.

### Recommendation

Option A. It is the only option that keeps the private-bucket and per-surface boundaries
server-derived without widening CSP, and it matches "No URL parameter or client prop can choose an
identity". It requires approval of the new routes and of the static default image for app.

## 2. Emergency Secret Credential commit acknowledgement (Phase 7, item 6)

### Observed facts

- `ClientSecretCredential` is an `AppPrincipalRecord`, which is on the `app_zenith` database.
- `ClientRpSession` and `ClientToken` are `AppTicketRecord`s, on the `app_ticket` database.
- The plan requires durable exclusion before an RP session can be created, the RP session commit
  before consume, and unknown outcomes staying claimed and failing closed. Because the claim and the
  session are in different databases, no single transaction can prove "session committed and
  credential consumed".

### Options

| Option | Description | Trade-offs |
| --- | --- | --- |
| A. Operation record co-located with the session | In `app_zenith`: lock the credential row and mark it `claimed` with a new `operation_id`. In one `app_ticket` transaction: insert the RP session and an `emergency_sign_in_operations(operation_id UNIQUE, credential_ref)` row. Then consume the credential in `app_zenith` only if that operation row exists; a retry with the same `operation_id` reconciles by checking the operation row | The operation row is the trusted, same-transaction proof of the session commit. It adds one small table to `app_ticket` (a migration needing approval). A crash between the steps leaves the credential `claimed`, which fails closed and is reconciled by `operation_id`. |
| B. Move the Credential to `app_ticket` | Store the temporary credential alongside RP sessions so claim, session, and consume share one transaction | The strongest guarantee, but it moves an identity-owned credential into the ticket database, conflicting with the current principal-ownership boundary (`adr/identity-authority-boundary.md`). It needs an ADR change. |
| C. Keep the endpoint disabled | Keep Emergency sign-in behavior inactive; `/sign/in/emergency` reserves only a read-only placeholder | No risk, but no feature. |

### Recommendation

Option A. It satisfies every stated condition (durable exclusion first, committed session proof,
fail-closed unknown outcome, same-operation reconciliation) without moving ownership. It requires
approval of the `app_ticket` migration and of the operation-record schema under
`generic/data-shape-design.mdc`.

## Items that remain outside local implementation

Real Turnstile Siteverify verification, populated-data Avatar/Persona cutover, legacy App `LOGIN`
row revocation on populated databases, and production Warp keys and deployment need external access
or explicit persistent-write approval, and are not decided here.
