# First-party BCL removal (Step 6, REQ-007 / AT-007)

- Base commit: `6e2c36b93a96737f36403f6a644bfc0ad0404b1f` on `feature`. The removal was verified as
  staged, uncommitted changes on top of that commit and committed right afterwards.
- Actor: Claude Opus 5.5 (claude-opus-5-5), taking over from the Codex implementation session.

## Precondition

- Consumer map: on 2026-10-15 the user stated that no RP outside the first-party set receives
  back-channel logout. This replaces the external-consumer gate that kept AT-007 BLOCKED in
  `evidence/2026-10-13-bcl-queue-inventory-K2V9.md`.
- Queue: that record observed `pending_delivery_jobs=0` in `development_queue_db`. No production
  queue was inspected. Before deployment, any queued `OidcBackchannelLogoutDeliveryJob` rows must be
  drained or classified (see "Not verified").

## Removed

- Sender: the `notify_oidc_rps_of_logout` call and helpers in `SignOidcLogout`,
  `OidcBackchannelLogoutNotifier`, `OidcBackchannelLogoutDeliveryJob`, and the BCL envelope in
  `OutboundSensitivePayload` (including `decrypt_envelope`, which had no other caller).
- Receivers: the Core app/com/org and Edit org `oidc/backchannel/logout` routes and controllers,
  `OidcRpLogoutReceiver`, `OidcRpSessionLogout` and `OidcLogoutTokenCodec`.
- Declarations: `backchannel_logout_uris` and `backchannel_logout_session_required` in the static
  client store, the registry value and its helpers, the regional client matrix and the token
  exchange client copy, plus the two discovery `backchannel_logout_*` claims.
- BCL-only leftovers: the `oidc_backchannel_logout_suspended` flag, `OidcClientFlipperActor` (whose
  only consumer was that gate), and the `oidc_logout_token` consumed-JTI purpose. The purpose had no
  DB constraint or validation. Stored rows were not purged; they age out through
  `SecurityConsumedJtiPurgeJob`.
- Tests whose only subject was a removed component were deleted. Route, CSRF, no-store and registry
  tests now assert that the routes, metadata and declarations are absent.

## Commands and results

- `bin/rubocop` on 37 modified Ruby files: no offenses.
- `RAILS_ENV=test bin/rails runner` eager load: succeeded; 0 routes contain `backchannel`.
- `PARALLEL_WORKERS=1 bin/rails test` on the modified tests plus `test/controllers/core`,
  `test/controllers/edit/org`, the completion matrix, the authority-first logout test and
  `test/services/outbound_sensitive_payload_test.rb`: 414 runs, 1 failure. The failure was the
  retargeted `decrypt_envelope` case. After it was moved to `decrypt_sms_delivery`, the rerun of
  that file with `test/jobs` and `test/services/oidc` gave 388 runs, 0 failures, 1 error. The error
  is the known Avatar `committed tests require run-owned worker receipts` guard
  (`AvatarRetentionPurgeTest`), which is unrelated to this change.
- `grep` over `app`, `config` and `lib` finds no BCL symbol. The only `backchannel` strings left are
  the Auth routes comments, which state that the route is absent.

## Not verified

- Production or other non-development queues were not inspected for undelivered jobs. A queued job
  of the removed class would fail to deserialize after deployment. This is a release condition.
- The full Minitest suite was not rerun for this step.
