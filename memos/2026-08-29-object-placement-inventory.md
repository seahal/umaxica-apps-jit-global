# Object Placement Inventory

Audit of where non-model, non-controller objects actually live, and what they actually are. Input
for the placement work tracked in #858. This is a memo: exploratory audit output, not source of
truth (`project/repository-knowledge-tree.mdc`).

Counts were regenerated from the tree on 2026-08-29 and will drift as the moves land.

Historical entries for `SignAppUpTelephoneSignupCreator`, `SignComUpTelephoneSignupCreator` and
`SignTelephoneOtpDelivery` were retired on 2026-10-08. Current signup uses the independent
`TelephoneSignUpCandidateCreator` and ceremony-owned Telephone issuer/delivery operations;
this historical inventory is not evidence that the retired definitions still exist.

## Method, and its limits

Each file's role was derived from three signals rather than from its name:

1. Superclass or `module_function`.
2. Whether any ActiveRecord write appears anywhere in the body (`create`, `update`, `save`,
   `destroy`, `delete_all`, `upsert`, `touch`, `transaction`, and the bang variants).
3. The public method list.

Files whose suffix and body disagreed were then opened and read. **The confidence column says which
is which**: `high` means the body was read during this audit, `med` means the signals were
unambiguous and consistent, `low` means the file must be opened before it is moved. 30 rows are
high, 165 med, 41 low.

**Later corrections to this memo**, kept here rather than edited away:
`memos/2026-08-29-ceremony-store-diagnosis.md` supersedes the store findings, and
`memos/2026-08-29-chronicle-and-enforcement-write-dependencies.md` supersedes the dependency
findings.

The signal pass is a first cut, not a verdict. A `med` row is a hypothesis with evidence, and the
issue that moves the file is responsible for confirming it.

## Root counts

| Root              | Files |
| ----------------- | ----- |
| `app/policies`    | 383   |
| `app/services`    | 236   |
| `app/values`      | 96    |
| `app/adapters`    | 23    |
| `app/errors`      | 19    |
| `app/lib`         | 10    |
| `app/presenters`  | 6     |
| `app/notifiers`   | 5     |
| `app/validators`  | 4     |
| `app/forms`       | 3     |
| `app/operations`  | 3     |
| `app/subscribers` | 3     |
| `app/queries`     | 2     |
| `app/resolvers`   | 1     |
| `app/consumers`   | **0** |

`app/consumers` exists and is empty while 8 `*_consumer.rb` sit in `app/services`.

## How the drift stayed invisible

- Of 236 files in `app/services`, only **46** inherit `ApplicationService`. 158 are plain classes
  with no superclass and 13 are `module_function` modules. There is no type to check, so nothing
  distinguished a service from anything else filed beside it.
- The 236 files carry **115 distinct name suffixes**. Only **9** end in `service`.
- Because the root is flat (`docs/architecture/flat-ruby-source-layout.md`), a file's path says
  nothing about its role either. Role lived only in the suffix, and the suffix was never enforced.

## Where the roles actually fall

| Role       | Files | Target root                           |
| ---------- | ----- | ------------------------------------- |
| Operation  | 106   | `app/operations`                      |
| Service    | 31    | `app/services`                        |
| Value      | 19    | `app/values`                          |
| Resolver   | 11    | `app/resolvers`                       |
| Store      | 11    | undecided, see #867                   |
| Verifier   | 11    | `app/adapters` or `app/lib`, see #866 |
| REVIEW     | 11    | undecided                             |
| Lib        | 8     | `app/lib`                             |
| Consumer   | 8     | `app/consumers`                       |
| Policy     | 8     | `app/policies`                        |
| Query      | 6     | `app/queries`                         |
| Adapter    | 3     | `app/adapters`                        |
| Registry   | 2     | `app/values`                          |
| Serializer | 1     | `app/serializers`                     |

**31 of 236 files are Services under this repository's own definition.** The root is 87 percent
things that are not services.

## Corrections to earlier estimates

The audit contradicts figures used when the issues were filed. The issues are wrong where they
disagree with this memo.

- **"50 write-side files" (#868) is an undercount, and the group is not homogeneous.** 106 files
  perform a state change. But `Issuer` is at least two different roles: `AcmeRefreshTokenIssuer`
  rotates a persisted token (`update_columns`, reuse handling) and is an Operation, while
  `JumpRtIssuer`, `OidcIdTokenIssuer` and `IdentityStepUpCeremonyResultIssuer` only build and sign a
  payload and persist nothing. The latter are primitives, not operations, and belong in `app/lib`. A
  bulk move keyed on the `Issuer` suffix would have put them in the wrong root.
- **"14 stores" (#867) is four different things**, and the claim that all 14 wrap ActiveRecord is
  itself wrong — see `memos/2026-08-29-ceremony-store-diagnosis.md`, which supersedes this entry.
  Originally recorded as three: Seven `*_replay_store` files pair `.for(surface)` dispatch with
  `create_transaction!` / `find_transaction!`. Three `*_candidate_store` files are genuine keyed
  stores with a `store! / fetch! / consume! / delete` lifecycle. `dpop_proof_state_store.rb` is
  neither: its whole body is a `case` returning an ActiveRecord class, which makes it a Resolver
  whose suffix is simply wrong. `turnstile_replay_store.rb` is a single write (`consume!`), so it is
  an Operation.
- **"4 validators" was wrong; there are 3** — `dbsc_proof_validator.rb`, `dpop_proof_validator.rb`,
  `oidc_authorize_request_validator.rb`.

## Correction to the placement rule written in #859

Three suffixes admitted by the rule are contradicted by the code they were meant to describe. The
rule needs a follow-up amendment; it should not be treated as settled on these points.

- **`Guard` and `Authority` are allowed under `app/policies`, but the objects carrying those names
  write.** `BaseSelectorBootstrapAuthority` runs `create` and `find_or_create_by` inside a
  transaction. `SignUpEmailPendingGuard` takes a lock and saves. `DpopJtiReplayGuard.record!`
  persists a replay entry. `SignRiskEnforcer` exposes `revoke!` and `require_step_up!`. A Policy is
  defined as having no side effects, so either these names leave `app/policies` or the rule stops
  admitting them.
- **`Locator` is allowed under `app/queries`, but both locators write.** `SignInCycleLocator` and
  `SignUpCycleLocator` expose `issue!`, `rotate!`, and `clear!`.

## `app/services` is not actually flat

`docs/architecture/flat-ruby-source-layout.md` names `app/services` as a flat root, but **20 of the
236 files are nested and namespaced**: `AvatarBackfill::`, `AvatarProvisioning::`,
`CollectiveMembership::` (7 files), `GroupAvatarMemberships::` (3), `GroupManagement::` (3), and
`Webauthn::` (4).

This matters for every move issue. A file in the flat part keeps its constant when it moves to
another flat root, so the move is a `git mv`. A file in the nested part does not, and neither does a
flat file moving into a nested root. The two halves need different handling and the count is not
small enough to treat as a footnote.

The nested group is also the most consistently named part of the root -
`CollectiveMembership::Accept`, `GroupManagement::Archive` - and those names carry no role suffix at
all, so applying the suffix rule to them is a constant rename on top of a move.

## Objects that need a decision, not a move

- `authentication_session_committer.rb` calls `controller.send(:establish_signed_in_session!)`. It
  reaches back into the controller and uses `send` to bypass a private method. The dependency runs
  the wrong way and the privacy boundary is deliberately circumvented; relocating the file changes
  neither.
- `chronicle_fallback_recorder.rb` is named `Recorder` but its `call` only writes
  `Rails.logger.error`. Under `adr/application-logging-boundary.md` a log is not the authoritative
  record, so a "recorder" that only logs is either misnamed or is a deliberate degraded path that
  should say so. Resolve with #869.
- `acme_selectable_context.rb` exposes `selectable_candidates` alongside `persist_selection!`: a
  query and a write in one object.
- `social_auth_callback_state_store.rb` pairs `issue!` / `consume!` with `state_class_for` dispatch
  — the same mixed shape as the replay stores.

## Non-values living in `app/values`

`app/values` holds 96 files. These are not values:

| File                                                                                                                                                                                            | What it is                       | Target               |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- | -------------------- |
| `oidc_client_secret_resolver.rb`                                                                                                                                                                | reads `Rails.app.creds`          | `app/resolvers`      |
| `account_standing_resolver.rb`                                                                                                                                                                  | derives a value                  | `app/resolvers`      |
| `webauthn/options_serializer.rb`                                                                                                                                                                | shapes a payload                 | `app/serializers`    |
| `oidc_logout_token_codec.rb`, `security_jwt_auth_access_token_codec.rb`, `security_jwt_jump_rt_token_codec.rb`, `security_jwt_oidc_id_token_codec.rb`, `security_jwt_preference_token_codec.rb` | encode/decode primitives         | `app/lib`            |
| `external_authentication/provider_registry.rb`, `fqdn_availability_registry.rb`, `regional_root_url_registry.rb`                                                                                | static catalogs                  | stay in `app/values` |
| `oidc_client_stores_static_client_store.rb`                                                                                                                                                     | static catalog named `Store`     | rename, stay         |
| `common_otp_policy.rb`, `webauthn/uv_policy.rb`                                                                                                                                                 | configuration, not authorization | rename per the rule  |
| `jump_rt_return_verifier.rb`                                                                                                                                                                    | verifies a returned token        | `app/lib`, see #866  |

20 files end in `_result.rb`, which is already the Result Object convention and needs no change.

## Unsuffixed files in roles that require a suffix

- `app/operations/publishing/move_taxonomy_subtree.rb`, `promote_revision.rb`, `restore_version.rb`
- `app/presenters/auth/app/settings/activity_log.rb` and its `com`, `org`, and `base/*` siblings
- `app/queries/current_banner.rb`, `step_up_configured_methods.rb`
- `app/notifiers/notify/otp_issuance.rb`

## Dependency inversion

**Correction.** The counts first reported here were 16 and 12. Those greps matched comments as well
as code. Stripping comment text gives **13 constants referenced from `app/models` and 10 from
`app/models/concerns`**; `RetentionCrossDatabaseChildPurge`, `WithdrawalPersonalDataAnonymizer`, and
`SignUpRequirementRegistry` appear only in prose and are not dependencies at all.

The 13 code references from `app/models`:

```
AdministrativeAccessLock AuthMethodGuard AuthenticationCredentialInventory
ChronicleFallbackRecorder ChronicleIntentWriter ChronicleInvalidator ChronicleRecorder
ChronicleResultWriter EnforcementIdentifierDigest IdentifierBlindIndex
IdentityTelephoneCeremony OidcClientRegistry PromotionalEmailUnsubscribeToken
```

The 10 from `app/models/concerns` are the same list without `AuthMethodGuard`, `ChronicleRecorder`,
and `EnforcementIdentifierDigest`.

Reproduce with:

```bash
find app/services -name '*.rb' | sed 's#app/services/##;s#\.rb$##;s#/#_#g' \
  | awk -F_ '{s="";for(i=1;i<=NF;i++){s=s toupper(substr($i,1,1)) substr($i,2)}; print s}' | sort -u > /tmp/svc.txt
grep -rhoE '\b[A-Z][A-Za-z0-9]+\b' app/models --include='*.rb' | sort -u > /tmp/m.txt
comm -12 /tmp/svc.txt /tmp/m.txt
```

That reproduction still counts comments. Pipe each file through `sed 's/#.*//'` first for the
code-only figures quoted above.

Most of these are not services, so the inverted arrow is an artifact of placement and disappears
when the object moves: `IdentifierBlindIndex` and `EnforcementIdentifierDigest` are HMAC primitives
for `app/lib`, `OidcClientRegistry` and `SignUpRequirementRegistry` are catalogs for `app/values`,
`AuthenticationCredentialInventory` is a query, `ChronicleRecorder` is sanitization and retention
policy with no writes at all.

`AuthMethodGuard` is a narrower case still: `app/models/client.rb:307` references only its frozen
`VERIFIED_EMAIL_STATUSES` constant, not its behavior. The status lists are a value; extracting them
removes the dependency without moving the guard at all.

Four were recorded here as genuine violations of the same shape - a model concern invoking a write
operation. **That was wrong on both counts**, and
`memos/2026-08-29-chronicle-and-enforcement-write-dependencies.md` supersedes this paragraph.

Neither site is a callback, which is how this memo and the issues described them. And they are not
the same problem: the Chronicle writers write `Chronicle` rows, so the audit model is persisting its
own records through extracted steps, while `AdministrativeAccessLock.lock!` is called from
`EnforcementCase#apply!`, a use case implemented as a model method. Only the second is a layering
problem, and the fix for it is to extract `apply!`, not to move a file.

## Full classification

| File                                                              | Constant                                                 | Role       | Target root                         | Conf. | Note                                                        |
| ----------------------------------------------------------------- | -------------------------------------------------------- | ---------- | ----------------------------------- | ----- | ----------------------------------------------------------- |
| `account_session_revocation.rb`                                   | `AccountSessionRevocation`                               | Operation  | `app/operations`                    | med   | inherits ApplicationService                                 |
| `acme_logout_transaction_coordinator.rb`                          | `AcmeLogoutTransactionCoordinator`                       | Service    | `app/services`                      | med   | inherits ApplicationService                                 |
| `acme_refresh_token_issuer.rb`                                    | `AcmeRefreshTokenIssuer`                                 | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `acme_selectable_context.rb`                                      | `AcmeSelectableContext`                                  | REVIEW     | `undecided`                         | high  | persist_selection! mixes a query with a write               |
| `acme_selector.rb`                                                | `AcmeSelector`                                           | Resolver   | `app/resolvers`                     | med   | -                                                           |
| `acme_selector_surface_config.rb`                                 | ``                                                       | Value      | `app/values`                        | med   | -                                                           |
| `administrative_access_lock.rb`                                   | `AdministrativeAccessLock`                               | Operation  | `app/operations`                    | med   | inherits ApplicationService                                 |
| `analytics_consent_guard.rb`                                      | `AnalyticsConsentGuard`                                  | Policy     | `app/policies`                      | med   | -                                                           |
| `analytics_consent_guard_pre_consent_allowlist.rb`                | `AnalyticsConsentGuardPreConsentAllowlist`               | Query      | `app/queries`                       | med   | -                                                           |
| `api_problem_exceptions_app.rb`                                   | `ApiProblemExceptionsApp`                                | Lib        | `app/lib`                           | med   | a Rack app, not a domain object                             |
| `apple_only_credential_status.rb`                                 | `AppleOnlyCredentialStatus`                              | Query      | `app/queries`                       | med   | -                                                           |
| `application_service.rb`                                          | `ApplicationService`                                     | Service    | `app/services`                      | med   | -                                                           |
| `auth_authorization_header.rb`                                    | `AuthAuthorizationHeader`                                | Value      | `app/values`                        | med   | -                                                           |
| `auth_method_guard.rb`                                            | `AuthMethodGuard`                                        | Policy     | `app/policies`                      | med   | -                                                           |
| `authentication_credential_inventory.rb`                          | `AuthenticationCredentialInventory`                      | Query      | `app/queries`                       | med   | -                                                           |
| `authentication_other_sessions_revoker.rb`                        | `AuthenticationOtherSessionsRevoker`                     | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `authentication_rate_limit_key.rb`                                | `AuthenticationRateLimitKey`                             | Value      | `app/values`                        | med   | -                                                           |
| `authentication_security_event_emitter.rb`                        | `AuthenticationSecurityEventEmitter`                     | Operation  | `app/operations`                    | med   | -                                                           |
| `authentication_selected_session_revoker.rb`                      | `AuthenticationSelectedSessionRevoker`                   | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `authentication_session_committer.rb`                             | `AuthenticationSessionCommitter`                         | REVIEW     | `undecided`                         | high  | calls controller.send(:establish_signed_in_session!)        |
| `avatar_backfill/audit_legacy_client_bindings.rb`                 | `AvatarBackfill::AuditLegacyClientBindings`              | Operation  | `app/operations`                    | high  | create                                                      |
| `avatar_backfill/backfill_legacy_client_bindings.rb`              | `AvatarBackfill::BackfillLegacyClientBindings`           | Operation  | `app/operations`                    | high  | create inside a transaction                                 |
| `avatar_lifecycle.rb`                                             | `AvatarLifecycle`                                        | Service    | `app/services`                      | med   | -                                                           |
| `avatar_provisioning/create.rb`                                   | `AvatarProvisioning::Create`                             | Operation  | `app/operations`                    | med   | -                                                           |
| `avatar_social_graph.rb`                                          | `AvatarSocialGraph`                                      | Operation  | `app/operations`                    | high  | create_follow, destroy_all                                  |
| `base_selector_authority.rb`                                      | `BaseSelectorAuthority`                                  | Policy     | `app/policies`                      | med   | -                                                           |
| `base_selector_bootstrap_authority.rb`                            | `BaseSelectorBootstrapAuthority`                         | Operation  | `app/operations`                    | high  | create/find_or_create_by inside a transaction               |
| `base_switcher_authority.rb`                                      | `BaseSwitcherAuthority`                                  | Policy     | `app/policies`                      | med   | -                                                           |
| `chronicle_application_service.rb`                                | `ChronicleApplicationService`                            | Service    | `app/services`                      | med   | -                                                           |
| `chronicle_fallback_recorder.rb`                                  | `ChronicleFallbackRecorder`                              | REVIEW     | `undecided`                         | high  | only Rails.logger.error; a Recorder that records nothing    |
| `chronicle_intent_writer.rb`                                      | `ChronicleIntentWriter`                                  | Operation  | `app/operations`                    | med   | -                                                           |
| `chronicle_invalidator.rb`                                        | `ChronicleInvalidator`                                   | Operation  | `app/operations`                    | med   | -                                                           |
| `chronicle_recorder.rb`                                           | `ChronicleRecorder`                                      | Policy     | `app/policies`                      | high  | sanitize/retention_policy_for/log_payload; no writes        |
| `chronicle_result_writer.rb`                                      | `ChronicleResultWriter`                                  | Operation  | `app/operations`                    | med   | -                                                           |
| `client_secret_credentials_create.rb`                             | `ClientSecretCredentialsCreate`                          | Operation  | `app/operations`                    | med   | -                                                           |
| `client_secret_credentials_destroy.rb`                            | `ClientSecretCredentialsDestroy`                         | Operation  | `app/operations`                    | med   | -                                                           |
| `client_secret_credentials_update.rb`                             | `ClientSecretCredentialsUpdate`                          | Operation  | `app/operations`                    | med   | -                                                           |
| `collective_membership/accept.rb`                                 | `CollectiveMembership::Accept`                           | Operation  | `app/operations`                    | med   | -                                                           |
| `collective_membership/errors.rb`                                 | `CollectiveMembership::Errors`                           | Value      | `app/values`                        | med   | -                                                           |
| `collective_membership/grant.rb`                                  | `CollectiveMembership::Grant`                            | Operation  | `app/operations`                    | high  | create inside a transaction                                 |
| `collective_membership/make_primary.rb`                           | `CollectiveMembership::MakePrimary`                      | Operation  | `app/operations`                    | high  | update inside a transaction                                 |
| `collective_membership/revoke.rb`                                 | `CollectiveMembership::Revoke`                           | Operation  | `app/operations`                    | med   | -                                                           |
| `collective_membership/suspend.rb`                                | `CollectiveMembership::Suspend`                          | Operation  | `app/operations`                    | med   | -                                                           |
| `collective_membership/transfer_unit.rb`                          | `CollectiveMembership::TransferUnit`                     | Operation  | `app/operations`                    | high  | update                                                      |
| `core_browser_credential_contract.rb`                             | `CoreBrowserCredentialContract`                          | Value      | `app/values`                        | med   | -                                                           |
| `credential_security_transition.rb`                               | `CredentialSecurityTransition`                           | REVIEW     | `undecided`                         | low   | -                                                           |
| `csp_violation_report_intake.rb`                                  | `CspViolationReportIntake`                               | Value      | `app/values`                        | high  | parses and normalizes report bodies; no writes              |
| `dbsc_proof_validator.rb`                                         | `DbscProofValidator`                                     | Verifier   | `app/adapters or app/lib, see #866` | low   | -                                                           |
| `dbsc_record_adapter.rb`                                          | `DbscRecordAdapter`                                      | Verifier   | `app/adapters or app/lib, see #866` | low   | -                                                           |
| `dbsc_registration_service.rb`                                    | `DbscRegistrationService`                                | Service    | `app/services`                      | med   | inherits ApplicationService                                 |
| `dbsc_verification_service.rb`                                    | `DbscVerificationService`                                | Service    | `app/services`                      | med   | inherits ApplicationService                                 |
| `dpop_jti_replay_guard.rb`                                        | `DpopJtiReplayGuard`                                     | Operation  | `app/operations`                    | high  | record! persists a replay entry                             |
| `dpop_nonce_service.rb`                                           | `DpopNonceService`                                       | Service    | `app/services`                      | med   | -                                                           |
| `dpop_proof_state_store.rb`                                       | `DpopProofStateStore`                                    | Resolver   | `app/resolvers`                     | high  | body is a case returning an AR class; Store suffix is wrong |
| `dpop_proof_validator.rb`                                         | `DpopProofValidator`                                     | Verifier   | `app/adapters or app/lib, see #866` | low   | -                                                           |
| `dpop_request_verifier.rb`                                        | `DpopRequestVerifier`                                    | Verifier   | `app/adapters or app/lib, see #866` | low   | -                                                           |
| `enforcement_identifier_digest.rb`                                | `EnforcementIdentifierDigest`                            | Lib        | `app/lib`                           | med   | -                                                           |
| `external_authentication_apple_notification_dead_letter_alert.rb` | `ExternalAuthenticationAppleNotificationDeadLetterAlert` | Value      | `app/values`                        | med   | -                                                           |
| `external_authentication_apple_notification_ingress.rb`           | `ExternalAuthenticationAppleNotificationIngress`         | Operation  | `app/operations`                    | med   | -                                                           |
| `external_authentication_apple_notification_processor.rb`         | `ExternalAuthenticationAppleNotificationProcessor`       | Operation  | `app/operations`                    | med   | -                                                           |
| `external_authentication_entra_redirect_uri.rb`                   | `ExternalAuthenticationEntraRedirectUri`                 | Value      | `app/values`                        | med   | -                                                           |
| `external_authentication_link_use_case.rb`                        | `ExternalAuthenticationLinkUseCase`                      | Service    | `app/services`                      | med   | -                                                           |
| `external_authentication_login_use_case.rb`                       | `ExternalAuthenticationLoginUseCase`                     | Service    | `app/services`                      | med   | -                                                           |
| `external_authentication_signup_use_case.rb`                      | `ExternalAuthenticationSignupUseCase`                    | Service    | `app/services`                      | med   | -                                                           |
| `external_authentication_unlink_use_case.rb`                      | `ExternalAuthenticationUnlinkUseCase`                    | Service    | `app/services`                      | med   | -                                                           |
| `group_avatar_memberships/attach.rb`                              | `GroupAvatarMemberships::Attach`                         | Operation  | `app/operations`                    | med   | -                                                           |
| `group_avatar_memberships/detach.rb`                              | `GroupAvatarMemberships::Detach`                         | Operation  | `app/operations`                    | med   | -                                                           |
| `group_avatar_memberships/reorder.rb`                             | `GroupAvatarMemberships::Reorder`                        | Operation  | `app/operations`                    | med   | -                                                           |
| `group_management/archive.rb`                                     | `GroupManagement::Archive`                               | Operation  | `app/operations`                    | med   | -                                                           |
| `group_management/create.rb`                                      | `GroupManagement::Create`                                | Operation  | `app/operations`                    | med   | -                                                           |
| `group_management/update.rb`                                      | `GroupManagement::Update`                                | Operation  | `app/operations`                    | med   | -                                                           |
| `health.rb`                                                       | `Health`                                                 | Query      | `app/queries`                       | med   | -                                                           |
| `host_context_resolver.rb`                                        | `HostContextResolver`                                    | Resolver   | `app/resolvers`                     | med   | -                                                           |
| `identifier_blind_index.rb`                                       | `IdentifierBlindIndex`                                   | Lib        | `app/lib`                           | med   | -                                                           |
| `identifier_blind_index_backfill.rb`                              | `IdentifierBlindIndexBackfill`                           | Operation  | `app/operations`                    | med   | -                                                           |
| `identifier_encryption_reencrypt.rb`                              | `IdentifierEncryptionReencrypt`                          | Operation  | `app/operations`                    | med   | -                                                           |
| `identifier_hmac_emergency_rotation.rb`                           | `IdentifierHmacEmergencyRotation`                        | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_audit.rb`                                               | `IdentityAudit`                                          | Operation  | `app/operations`                    | high  | record! creates an audit row                                |
| `identity_email_ceremony_final_committer.rb`                      | `IdentityEmailCeremonyFinalCommitter`                    | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_email_ceremony_replay_store.rb`                         | `IdentityEmailCeremonyReplayStore`                       | Store      | `undecided, see #867`               | med   | -                                                           |
| `identity_email_ceremony_result_consumer.rb`                      | `IdentityEmailCeremonyResultConsumer`                    | Consumer   | `app/consumers`                     | med   | -                                                           |
| `identity_email_ceremony_result_issuer.rb`                        | `IdentityEmailCeremonyResultIssuer`                      | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `identity_email_ceremony_transaction_purger.rb`                   | `IdentityEmailCeremonyTransactionPurger`                 | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_graph_provisioner.rb`                                   | `IdentityGraphProvisioner`                               | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `identity_one_time_reveal.rb`                                     | `IdentityOneTimeReveal`                                  | REVIEW     | `undecided`                         | low   | -                                                           |
| `identity_passkey_ceremony_final_committer.rb`                    | `IdentityPasskeyCeremonyFinalCommitter`                  | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_passkey_ceremony_replay_store.rb`                       | `IdentityPasskeyCeremonyReplayStore`                     | Store      | `undecided, see #867`               | med   | -                                                           |
| `identity_passkey_ceremony_result_consumer.rb`                    | `IdentityPasskeyCeremonyResultConsumer`                  | Consumer   | `app/consumers`                     | med   | -                                                           |
| `identity_passkey_ceremony_result_issuer.rb`                      | `IdentityPasskeyCeremonyResultIssuer`                    | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `identity_passkey_ceremony_transaction_purger.rb`                 | `IdentityPasskeyCeremonyTransactionPurger`               | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_secret_credential_ceremony_candidate_store.rb`          | `IdentitySecretCredentialCeremonyCandidateStore`         | Store      | `undecided, see #867`               | med   | -                                                           |
| `identity_secret_credential_ceremony_final_committer.rb`          | `IdentitySecretCredentialCeremonyFinalCommitter`         | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_secret_credential_ceremony_replay_store.rb`             | `IdentitySecretCredentialCeremonyReplayStore`            | Store      | `undecided, see #867`               | med   | -                                                           |
| `identity_secret_credential_ceremony_result_consumer.rb`          | `IdentitySecretCredentialCeremonyResultConsumer`         | Consumer   | `app/consumers`                     | med   | -                                                           |
| `identity_secret_credential_ceremony_result_issuer.rb`            | `IdentitySecretCredentialCeremonyResultIssuer`           | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_secret_credential_ceremony_transaction_purger.rb`       | `IdentitySecretCredentialCeremonyTransactionPurger`      | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_social_ceremony_candidate_store.rb`                     | `IdentitySocialCeremonyCandidateStore`                   | Store      | `undecided, see #867`               | med   | -                                                           |
| `identity_social_ceremony_final_committer.rb`                     | `IdentitySocialCeremonyFinalCommitter`                   | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_social_ceremony_grant_issuer.rb`                        | `IdentitySocialCeremonyGrantIssuer`                      | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `identity_social_ceremony_replay_store.rb`                        | `IdentitySocialCeremonyReplayStore`                      | Store      | `undecided, see #867`               | med   | -                                                           |
| `identity_social_ceremony_result_consumer.rb`                     | `IdentitySocialCeremonyResultConsumer`                   | Consumer   | `app/consumers`                     | med   | -                                                           |
| `identity_social_ceremony_result_issuer.rb`                       | `IdentitySocialCeremonyResultIssuer`                     | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `identity_social_ceremony_transaction_purger.rb`                  | `IdentitySocialCeremonyTransactionPurger`                | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_step_up_ceremony_freshness_committer.rb`                | `IdentityStepUpCeremonyFreshnessCommitter`               | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_step_up_ceremony_freshness_revoker.rb`                  | `IdentityStepUpCeremonyFreshnessRevoker`                 | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_step_up_ceremony_grant_issuer.rb`                       | `IdentityStepUpCeremonyGrantIssuer`                      | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `identity_step_up_ceremony_replay_store.rb`                       | `IdentityStepUpCeremonyReplayStore`                      | Store      | `undecided, see #867`               | med   | -                                                           |
| `identity_step_up_ceremony_result_consumer.rb`                    | `IdentityStepUpCeremonyResultConsumer`                   | Consumer   | `app/consumers`                     | med   | -                                                           |
| `identity_step_up_ceremony_result_issuer.rb`                      | `IdentityStepUpCeremonyResultIssuer`                     | Lib        | `app/lib`                           | high  | delegates to IdentityStepUpCeremonyResult.issue             |
| `identity_step_up_ceremony_transaction_purger.rb`                 | `IdentityStepUpCeremonyTransactionPurger`                | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_telephone_ceremony.rb`                                  | `IdentityTelephoneCeremony`                              | Service    | `app/services`                      | med   | -                                                           |
| `identity_telephone_ceremony_final_committer.rb`                  | `IdentityTelephoneCeremonyFinalCommitter`                | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_telephone_ceremony_replay_store.rb`                     | `IdentityTelephoneCeremonyReplayStore`                   | Store      | `undecided, see #867`               | med   | -                                                           |
| `identity_telephone_ceremony_result_consumer.rb`                  | `IdentityTelephoneCeremonyResultConsumer`                | Consumer   | `app/consumers`                     | med   | -                                                           |
| `identity_telephone_ceremony_result_issuer.rb`                    | `IdentityTelephoneCeremonyResultIssuer`                  | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `identity_telephone_ceremony_transaction_purger.rb`               | `IdentityTelephoneCeremonyTransactionPurger`             | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_totp_ceremony_candidate_store.rb`                       | `IdentityTotpCeremonyCandidateStore`                     | Store      | `undecided, see #867`               | med   | -                                                           |
| `identity_totp_ceremony_final_committer.rb`                       | `IdentityTotpCeremonyFinalCommitter`                     | Operation  | `app/operations`                    | med   | -                                                           |
| `identity_totp_ceremony_replay_store.rb`                          | `IdentityTotpCeremonyReplayStore`                        | Store      | `undecided, see #867`               | med   | -                                                           |
| `identity_totp_ceremony_result_consumer.rb`                       | `IdentityTotpCeremonyResultConsumer`                     | Consumer   | `app/consumers`                     | med   | -                                                           |
| `identity_totp_ceremony_result_issuer.rb`                         | `IdentityTotpCeremonyResultIssuer`                       | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `identity_totp_ceremony_transaction_purger.rb`                    | `IdentityTotpCeremonyTransactionPurger`                  | Operation  | `app/operations`                    | med   | -                                                           |
| `jit_security_jwt_anomaly_reporter.rb`                            | `JitSecurityJwtAnomalyReporter`                          | REVIEW     | `undecided`                         | low   | -                                                           |
| `jump_rt_issuer.rb`                                               | `JumpRtIssuer`                                           | Lib        | `app/lib`                           | high  | mints a signed jump token; no persistence                   |
| `oidc_access_token_authenticator.rb`                              | `OidcAccessTokenAuthenticator`                           | Verifier   | `app/adapters or app/lib, see #866` | low   | inherits ApplicationService                                 |
| `oidc_authorization_code_issuer.rb`                               | `OidcAuthorizationCodeIssuer`                            | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `oidc_authorization_transaction_coordinator.rb`                   | `OidcAuthorizationTransactionCoordinator`                | Service    | `app/services`                      | med   | inherits ApplicationService                                 |
| `oidc_authorize_coordinator.rb`                                   | `OidcAuthorizeCoordinator`                               | Service    | `app/services`                      | med   | inherits ApplicationService                                 |
| `oidc_authorize_request_validator.rb`                             | `OidcAuthorizeRequestValidator`                          | Verifier   | `app/adapters or app/lib, see #866` | low   | inherits ApplicationService                                 |
| `oidc_backchannel_logout_notifier.rb`                             | `OidcBackchannelLogoutNotifier`                          | REVIEW     | `undecided`                         | low   | inherits ApplicationService                                 |
| `oidc_client_registry.rb`                                         | `OidcClientRegistry`                                     | Registry   | `app/values`                        | med   | -                                                           |
| `oidc_connection_recorder.rb`                                     | `OidcConnectionRecorder`                                 | Operation  | `app/operations`                    | med   | inherits ApplicationService                                 |
| `oidc_connection_revoker.rb`                                      | `OidcConnectionRevoker`                                  | Operation  | `app/operations`                    | med   | inherits ApplicationService                                 |
| `oidc_end_session_request.rb`                                     | `OidcEndSessionRequest`                                  | Value      | `app/values`                        | low   | inherits ApplicationService                                 |
| `oidc_id_token_issuer.rb`                                         | `OidcIdTokenIssuer`                                      | Lib        | `app/lib`                           | high  | builds an ID token payload; no persistence                  |
| `oidc_id_token_verifier.rb`                                       | `OidcIdTokenVerifier`                                    | Verifier   | `app/adapters or app/lib, see #866` | low   | inherits ApplicationService                                 |
| `oidc_jwks_service.rb`                                            | `OidcJwksService`                                        | Service    | `app/services`                      | med   | -                                                           |
| `oidc_logout_request.rb`                                          | `OidcLogoutRequest`                                      | Value      | `app/values`                        | med   | -                                                           |
| `oidc_refresh_token_issuer.rb`                                    | `OidcRefreshTokenIssuer`                                 | Operation  | `app/operations`                    | med   | -                                                           |
| `oidc_rp_session_logout.rb`                                       | `OidcRpSessionLogout`                                    | REVIEW     | `undecided`                         | low   | inherits ApplicationService                                 |
| `oidc_rp_token_client.rb`                                         | `OidcRpTokenClient`                                      | Verifier   | `app/adapters or app/lib, see #866` | low   | inherits ApplicationService                                 |
| `oidc_token_exchange_coordinator.rb`                              | `OidcTokenExchangeCoordinator`                           | Service    | `app/services`                      | med   | inherits ApplicationService                                 |
| `oidc_token_revoker.rb`                                           | `OidcTokenRevoker`                                       | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `operator_entra_identity_activation.rb`                           | `OperatorEntraIdentityActivation`                        | Operation  | `app/operations`                    | med   | inherits ApplicationService                                 |
| `operator_entra_identity_provisioner.rb`                          | `OperatorEntraIdentityProvisioner`                       | Operation  | `app/operations`                    | med   | inherits ApplicationService                                 |
| `operator_secret_credentials_create.rb`                           | `OperatorSecretCredentialsCreate`                        | Operation  | `app/operations`                    | med   | -                                                           |
| `operator_secret_credentials_destroy.rb`                          | `OperatorSecretCredentialsDestroy`                       | Operation  | `app/operations`                    | med   | -                                                           |
| `operator_secret_credentials_update.rb`                           | `OperatorSecretCredentialsUpdate`                        | Operation  | `app/operations`                    | med   | -                                                           |
| `org_entra_sign_in_preflight.rb`                                  | `OrgEntraSignInPreflight`                                | Resolver   | `app/resolvers`                     | low   | inherits ApplicationService                                 |
| `org_invitation_service.rb`                                       | `OrgInvitationService`                                   | Service    | `app/services`                      | med   | -                                                           |
| `org_operator_lifecycle_approve.rb`                               | `OrgOperatorLifecycleApprove`                            | Operation  | `app/operations`                    | med   | -                                                           |
| `org_operator_lifecycle_execute.rb`                               | `OrgOperatorLifecycleExecute`                            | Operation  | `app/operations`                    | med   | -                                                           |
| `org_operator_lifecycle_invitation_acceptance.rb`                 | `OrgOperatorLifecycleInvitationAcceptance`               | Operation  | `app/operations`                    | med   | -                                                           |
| `org_operator_lifecycle_invitation_issuer.rb`                     | `OrgOperatorLifecycleInvitationIssuer`                   | Operation  | `app/operations`                    | med   | -                                                           |
| `org_operator_lifecycle_reject.rb`                                | `OrgOperatorLifecycleReject`                             | Operation  | `app/operations`                    | med   | -                                                           |
| `org_operator_lifecycle_request_create.rb`                        | `OrgOperatorLifecycleRequestCreate`                      | Operation  | `app/operations`                    | med   | -                                                           |
| `otp_email_notifier_rollout.rb`                                   | `OtpEmailNotifierRollout`                                | REVIEW     | `undecided`                         | low   | -                                                           |
| `outage_service.rb`                                               | `OutageService`                                          | Service    | `app/services`                      | med   | -                                                           |
| `outbound_channel_suspension.rb`                                  | `OutboundChannelSuspension`                              | Policy     | `app/policies`                      | high  | Flipper check returning suspended?                          |
| `outbound_sensitive_payload.rb`                                   | `OutboundSensitivePayload`                               | Lib        | `app/lib`                           | high  | encrypt/decrypt pairs; a codec                              |
| `outbound_sms.rb`                                                 | `OutboundSms`                                            | Adapter    | `app/adapters`                      | med   | deliver_now/deliver_later/provider                          |
| `outbound_sms_providers_aws_sns.rb`                               | `OutboundSmsProvidersAwsSns`                             | Adapter    | `app/adapters`                      | high  | AWS SNS client                                              |
| `outbound_sms_providers_test.rb`                                  | `OutboundSmsProvidersTest`                               | Adapter    | `app/adapters`                      | high  | test double provider for the SMS port                       |
| `palm_access_token_authenticator.rb`                              | `PalmAccessTokenAuthenticator`                           | Verifier   | `app/adapters or app/lib, see #866` | low   | inherits ApplicationService                                 |
| `palm_logout_coordinator.rb`                                      | `PalmLogoutCoordinator`                                  | Service    | `app/services`                      | med   | inherits ApplicationService                                 |
| `promotional_email_unsubscribe_token.rb`                          | `PromotionalEmailUnsubscribeToken`                       | Lib        | `app/lib`                           | med   | -                                                           |
| `publishing_edition_resolver.rb`                                  | `PublishingEditionResolver`                              | Resolver   | `app/resolvers`                     | low   | inherits ApplicationService                                 |
| `publishing_entries_cursor.rb`                                    | `PublishingEntriesCursor`                                | Query      | `app/queries`                       | med   | -                                                           |
| `publishing_entry_serializer.rb`                                  | `PublishingEntrySerializer`                              | Serializer | `app/serializers`                   | low   | inherits ApplicationService                                 |
| `publishing_published_entries_query.rb`                           | `PublishingPublishedEntriesQuery`                        | Query      | `app/queries`                       | low   | inherits ApplicationService                                 |
| `recovery_passcode_top_up.rb`                                     | `RecoveryPasscodeTopUp`                                  | Operation  | `app/operations`                    | high  | writes inside a transaction                                 |
| `redirects_external_target_resolver.rb`                           | `RedirectsExternalTargetResolver`                        | Resolver   | `app/resolvers`                     | med   | -                                                           |
| `redirects_jump_gateway_url.rb`                                   | `RedirectsJumpGatewayUrl`                                | Value      | `app/values`                        | med   | -                                                           |
| `redirects_navigation_target_resolver.rb`                         | `RedirectsNavigationTargetResolver`                      | Resolver   | `app/resolvers`                     | med   | -                                                           |
| `redirects_path_target_resolver.rb`                               | `RedirectsPathTargetResolver`                            | Resolver   | `app/resolvers`                     | med   | -                                                           |
| `redirects_priority_resolver.rb`                                  | `RedirectsPriorityResolver`                              | Resolver   | `app/resolvers`                     | med   | -                                                           |
| `request_context_contract.rb`                                     | `RequestContextContract`                                 | Value      | `app/values`                        | med   | -                                                           |
| `retention_cross_database_child_purge.rb`                         | `RetentionCrossDatabaseChildPurge`                       | Operation  | `app/operations`                    | med   | -                                                           |
| `session_limit_resolution_token_ref.rb`                           | `SessionLimitResolutionTokenRef`                         | Value      | `app/values`                        | med   | -                                                           |
| `sign_app_in_email_authentication_state.rb`                       | `SignAppInEmailAuthenticationState`                      | Operation  | `app/operations`                    | med   | store_existing!/clear! write session state                  |
| `sign_app_session_revoke_audit.rb`                                | `SignAppSessionRevokeAudit`                              | Value      | `app/values`                        | med   | -                                                           |
| `sign_app_up_social_cancellation.rb`                              | `SignAppUpSocialCancellation`                            | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `sign_app_up_telephone_registration_finalizer.rb`                 | `SignAppUpTelephoneRegistrationFinalizer`                | Operation  | `app/operations`                    | med   | -                                                           |
| `sign_app_up_telephone_signup_creator.rb`                         | `SignAppUpTelephoneSignupCreator`                        | Operation  | `app/operations`                    | med   | -                                                           |
| `sign_com_up_telephone_registration_finalizer.rb`                 | `SignComUpTelephoneRegistrationFinalizer`                | Operation  | `app/operations`                    | med   | -                                                           |
| `sign_com_up_telephone_signup_creator.rb`                         | `SignComUpTelephoneSignupCreator`                        | Operation  | `app/operations`                    | med   | -                                                           |
| `sign_in_activation_candidate_resolver.rb`                        | `SignInActivationCandidateResolver`                      | Resolver   | `app/resolvers`                     | med   | -                                                           |
| `sign_in_checkpoint_participant.rb`                               | `SignInCheckpointParticipant`                            | Service    | `app/services`                      | med   | -                                                           |
| `sign_in_cycle_locator.rb`                                        | `SignInCycleLocator`                                     | Operation  | `app/operations`                    | high  | issue!/rotate!/clear! write session cycle state             |
| `sign_in_dashboard_participant.rb`                                | `SignInDashboardParticipant`                             | Service    | `app/services`                      | med   | -                                                           |
| `sign_in_guardrail_participant.rb`                                | `SignInGuardrailParticipant`                             | Service    | `app/services`                      | med   | -                                                           |
| `sign_in_otp_resend_state.rb`                                     | `SignInOtpResendState`                                   | Value      | `app/values`                        | med   | -                                                           |
| `sign_in_otp_resender.rb`                                         | `SignInOtpResender`                                      | Operation  | `app/operations`                    | med   | -                                                           |
| `sign_in_return_participant.rb`                                   | `SignInReturnParticipant`                                | Service    | `app/services`                      | med   | -                                                           |
| `sign_in_selector_participant.rb`                                 | `SignInSelectorParticipant`                              | Service    | `app/services`                      | med   | -                                                           |
| `sign_in_sequence_carrier.rb`                                     | `SignInSequenceCarrier`                                  | Operation  | `app/operations`                    | med   | start!/advance!/fail!/clear! write sequence state           |
| `sign_in_session_limit_manager.rb`                                | `SignInSessionLimitManager`                              | Service    | `app/services`                      | med   | -                                                           |
| `sign_in_state_machine.rb`                                        | `SignInStateMachine`                                     | Service    | `app/services`                      | med   | -                                                           |
| `sign_otp_ceremony.rb`                                            | `SignOtpCeremony`                                        | Service    | `app/services`                      | med   | -                                                           |
| `sign_recovery_passcode_requirement.rb`                           | `SignRecoveryPasscodeRequirement`                        | Policy     | `app/policies`                      | med   | -                                                           |
| `sign_refresh_token_issuer.rb`                                    | `SignRefreshTokenIssuer`                                 | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `sign_risk_emitter.rb`                                            | `SignRiskEmitter`                                        | Operation  | `app/operations`                    | med   | -                                                           |
| `sign_risk_enforcer.rb`                                           | `SignRiskEnforcer`                                       | Operation  | `app/operations`                    | high  | revoke!/require_step_up! perform writes                     |
| `sign_risk_engine.rb`                                             | `SignRiskEngine`                                         | Service    | `app/services`                      | med   | -                                                           |
| `sign_secret_issue.rb`                                            | `SignSecretIssue`                                        | Operation  | `app/operations`                    | med   | -                                                           |
| `sign_secret_record_event.rb`                                     | `SignSecretRecordEvent`                                  | Value      | `app/values`                        | med   | -                                                           |
| `sign_secret_revoke.rb`                                           | `SignSecretRevoke`                                       | Operation  | `app/operations`                    | med   | -                                                           |
| `sign_secret_rotate.rb`                                           | `SignSecretRotate`                                       | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `sign_secret_verify.rb`                                           | `SignSecretVerify`                                       | REVIEW     | `undecided`                         | low   | -                                                           |
| `sign_telephone_otp_delivery.rb`                                  | `SignTelephoneOtpDelivery`                               | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `sign_up_artifact_cleanup.rb`                                     | `SignUpArtifactCleanup`                                  | Operation  | `app/operations`                    | med   | -                                                           |
| `sign_up_cancellation.rb`                                         | `SignUpCancellation`                                     | Operation  | `app/operations`                    | low   | no write signal in this file                                |
| `sign_up_cycle_locator.rb`                                        | `SignUpCycleLocator`                                     | Operation  | `app/operations`                    | high  | issue!/clear! write session cycle state                     |
| `sign_up_email_pending_guard.rb`                                  | `SignUpEmailPendingGuard`                                | Operation  | `app/operations`                    | high  | with_lock plus save inside a transaction                    |
| `sign_up_finalization_context.rb`                                 | ``                                                       | Value      | `app/values`                        | med   | -                                                           |
| `sign_up_requirement_registry.rb`                                 | `SignUpRequirementRegistry`                              | Registry   | `app/values`                        | med   | -                                                           |
| `sign_up_session_state.rb`                                        | `SignUpSessionState`                                     | Operation  | `app/operations`                    | med   | writes session state                                        |
| `sign_up_state_machine.rb`                                        | `SignUpStateMachine`                                     | Service    | `app/services`                      | med   | -                                                           |
| `sign_up_suspension.rb`                                           | `SignUpSuspension`                                       | Policy     | `app/policies`                      | high  | Flipper check returning suspended?                          |
| `sign_up_termination.rb`                                          | `SignUpTermination`                                      | Operation  | `app/operations`                    | med   | -                                                           |
| `social_auth_callback_state_store.rb`                             | `SocialAuthCallbackStateStore`                           | REVIEW     | `undecided`                         | high  | issue!/consume! plus state_class_for: dispatch and write    |
| `social_auth_link_handler.rb`                                     | `SocialAuthLinkHandler`                                  | Operation  | `app/operations`                    | med   | -                                                           |
| `social_auth_login_handler.rb`                                    | `SocialAuthLoginHandler`                                 | Operation  | `app/operations`                    | med   | -                                                           |
| `social_auth_signup_finalizer.rb`                                 | `SocialAuthSignupFinalizer`                              | Operation  | `app/operations`                    | med   | -                                                           |
| `step_up_cooldown_stamp.rb`                                       | `StepUpCooldownStamp`                                    | Value      | `app/values`                        | med   | -                                                           |
| `token_emergency_service.rb`                                      | `TokenEmergencyService`                                  | Service    | `app/services`                      | med   | -                                                           |
| `totp_window_consumer.rb`                                         | `TotpWindowConsumer`                                     | Consumer   | `app/consumers`                     | med   | -                                                           |
| `turnstile_degradation.rb`                                        | `TurnstileDegradation`                                   | Value      | `app/values`                        | med   | -                                                           |
| `turnstile_replay_store.rb`                                       | `TurnstileReplayStore`                                   | Operation  | `app/operations`                    | high  | consume! is a single write                                  |
| `visitor_secret_credentials_create.rb`                            | `VisitorSecretCredentialsCreate`                         | Operation  | `app/operations`                    | med   | -                                                           |
| `webauthn/assertion_verifier.rb`                                  | `Webauthn::AssertionVerifier`                            | Verifier   | `app/adapters or app/lib, see #866` | low   | -                                                           |
| `webauthn/authenticator_name_resolver.rb`                         | `Webauthn::AuthenticatorNameResolver`                    | Resolver   | `app/resolvers`                     | med   | -                                                           |
| `webauthn/challenge_store.rb`                                     | `Webauthn::ChallengeStore`                               | Store      | `undecided, see #867`               | med   | -                                                           |
| `webauthn/registration_verifier.rb`                               | `Webauthn::RegistrationVerifier`                         | Verifier   | `app/adapters or app/lib, see #866` | low   | -                                                           |
| `withdrawal_lifecycle.rb`                                         | `WithdrawalLifecycle`                                    | Service    | `app/services`                      | med   | -                                                           |
| `withdrawal_personal_data_anonymizer.rb`                          | `WithdrawalPersonalDataAnonymizer`                       | Operation  | `app/operations`                    | med   | -                                                           |
