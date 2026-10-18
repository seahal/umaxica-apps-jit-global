# Mechanical analysis of documented transition graphs

This analysis uses CURRENT node declarations and edges, not a Mermaid parser. Guards and time constraints are not solved: reachability is a conservative graph property, not a successful runtime execution claim. Aggregated nodes cannot prove per-value reachability. Terminal markers describe notation, not immutable storage. A nonterminal sink is a `DEAD_END_CANDIDATE`; external waits, unwired states, derived conditions and omitted writers require inspection. Absence of a path proves absence in the documented graph only. Writer coverage must close before this can prove implementation completeness.

The detailed per-axis results (no-inbound/no-outbound nodes, reachable nodes, SCCs and self-loops) and the script that produced this table were held in the removed `verification/` directory; this table cannot currently be regenerated from this directory.

| Axis | States | Edges | Initial | Terminal markers | Unreachable | DEAD_END_CANDIDATE | Cyclic components | Self-loops |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-sign-in | 11 | 26 | PRIMARY_PENDING | COMPLETED, FAILED | None | None | 1 | None |
| idp-client-sign-up | 14 | 40 | STARTED | COMPLETED, FAILED, EXPIRED, CANCELLED | None | None | 1 | CHECKPOINT_PENDING |
| idp-client-sign-out | 7 | 9 | REQUESTED | COMPLETED, FAILED | NOTHING | None | 0 | None |
| idp-client-auth-ceremony-session | 6 | 12 | issued, admitted | revoked, completed, cancelled | None | None | 3 | admitted, evidence, issued |
| idp-client-email-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-client-telephone-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-client-passkey-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-client-secret-credential-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-client-step-up-ceremony | 6 | 15 | pending | revoked, consumed, canceled | None | None | 1 | verified |
| idp-client-oidc-authorization | 3 | 5 | pending | consumed | None | None | 2 | authenticated, consumed |
| idp-client-oauth-callback | 2 | 1 | unconsumed | consumed | None | None | 0 | None |
| idp-client-local-result-delivery | 4 | 4 | empty | finalized | None | None | 1 | delivery |
| idp-client-token | 6 | 17 | ACTIVE, RESTRICTED | None | EXPIRED, NOTHING | rotated | 1 | ACTIVE, RESTRICTED, REVOKED |
| idp-client-dbsc | 5 | 9 | NOTHING, PENDING | None | FAILED, REVOKE | None | 1 | ACTIVE |
| idp-client-device-session | 2 | 4 | ACTIVE | REVOKED | None | None | 2 | ACTIVE, REVOKED |
| idp-client-rp-session | 3 | 4 | active | retired | None | None | 2 | active, revoked |
| idp-client-passkey-credential | 5 | 13 | ACTIVE | REVOKED | DISABLED, NOTHING | None | 1 | DELETED, REVOKED |
| idp-visitor-sign-in | 11 | 26 | PRIMARY_PENDING | COMPLETED, FAILED | None | None | 1 | None |
| idp-visitor-sign-up | 13 | 33 | STARTED | COMPLETED, FAILED, EXPIRED, CANCELLED | None | None | 1 | CHECKPOINT_PENDING |
| idp-visitor-sign-out | 7 | 9 | REQUESTED | COMPLETED, FAILED | NOTHING | None | 0 | None |
| idp-visitor-auth-ceremony-session | 6 | 12 | issued, admitted | revoked, completed, cancelled | None | None | 3 | admitted, evidence, issued |
| idp-visitor-email-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-visitor-telephone-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-visitor-passkey-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-visitor-secret-credential-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-visitor-step-up-ceremony | 6 | 15 | pending | revoked, consumed, canceled | None | None | 1 | verified |
| idp-visitor-oidc-authorization | 3 | 5 | pending | consumed | None | None | 2 | authenticated, consumed |
| idp-visitor-local-result-delivery | 4 | 4 | empty | finalized | None | None | 1 | delivery |
| idp-visitor-token | 6 | 17 | ACTIVE, RESTRICTED | None | EXPIRED, NOTHING | rotated | 1 | ACTIVE, RESTRICTED, REVOKED |
| idp-visitor-dbsc | 5 | 9 | NOTHING, PENDING | None | FAILED, REVOKE | None | 1 | ACTIVE |
| idp-visitor-device-session | 2 | 4 | ACTIVE | REVOKED | None | None | 2 | ACTIVE, REVOKED |
| idp-visitor-rp-session | 3 | 4 | active | retired | None | None | 2 | active, revoked |
| idp-visitor-passkey-credential | 5 | 13 | ACTIVE | REVOKED | DISABLED, NOTHING | None | 1 | DELETED, REVOKED |
| idp-operator-sign-in | 11 | 26 | PRIMARY_PENDING | COMPLETED, FAILED | None | None | 1 | None |
| idp-operator-sign-up | 5 | 10 | STARTED | COMPLETED | None | None | 0 | None |
| idp-operator-sign-out | 7 | 9 | REQUESTED | COMPLETED, FAILED | NOTHING | None | 0 | None |
| idp-operator-auth-ceremony-session | 6 | 12 | issued, admitted | revoked, completed, cancelled | None | None | 3 | admitted, evidence, issued |
| idp-operator-email-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-operator-telephone-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-operator-passkey-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-operator-secret-credential-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-operator-step-up-ceremony | 6 | 15 | pending | revoked, consumed, canceled | None | None | 1 | verified |
| idp-operator-oidc-authorization | 3 | 5 | pending | consumed | None | None | 2 | authenticated, consumed |
| idp-operator-oauth-callback | 2 | 1 | unconsumed | consumed | None | None | 0 | None |
| idp-operator-local-result-delivery | 4 | 4 | empty | finalized | None | None | 1 | delivery |
| idp-operator-token | 6 | 17 | ACTIVE, RESTRICTED | None | EXPIRED, NOTHING | rotated | 1 | ACTIVE, RESTRICTED, REVOKED |
| idp-operator-dbsc | 5 | 9 | NOTHING, PENDING | None | FAILED, REVOKE | None | 1 | ACTIVE |
| idp-operator-device-session | 2 | 4 | ACTIVE | REVOKED | None | None | 2 | ACTIVE, REVOKED |
| idp-operator-rp-session | 3 | 4 | active | retired | None | None | 2 | active, revoked |
| idp-operator-passkey-credential | 2 | 1 | ACTIVE | REVOKED | None | None | 0 | None |
| idp-client-sign-up-cleanup | 5 | 8 | IDLE | COMPLETED | NOTHING | None | 1 | PENDING |
| idp-client-withdrawal-ceremony | 4 | 8 | ACTIVE | None | EXPIRED | None | 1 | CONSUMED, REVOKED |
| idp-client-enforcement-recovery-ceremony | 3 | 6 | ACTIVE | None | None | None | 1 | CONSUMED, REVOKED |
| idp-visitor-sign-up-cleanup | 5 | 8 | IDLE | COMPLETED | NOTHING | None | 1 | PENDING |
| idp-visitor-withdrawal-ceremony | 4 | 8 | ACTIVE | None | EXPIRED | None | 1 | CONSUMED, REVOKED |
| idp-visitor-enforcement-recovery-ceremony | 3 | 6 | ACTIVE | None | None | None | 1 | CONSUMED, REVOKED |
| idp-client-totp-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-client-social-ceremony | 2 | 1 | pending | consumed | None | None | 0 | None |
| idp-client-secret-issuance | 6 | 5 | pending_presentation, omitted | confirmed, canceled, expired, omitted | confirmed, pending_confirmation | None | 0 | None |
| idp-client-session-limit-resolution | 5 | 15 | pending | None | expired | None | 1 | cancelled, resolved, session_selected |
| idp-client-apple-notification | 4 | 6 | received | completed, dead_letter | None | None | 1 | retrying |
| idp-client-external-identity | 3 | 6 | active | account_deleted | None | None | 1 | active, consent_revoked |
| idp-client-totp-credential | 5 | 11 | NOTHING, ACTIVE | REVOKED, DELETED | INACTIVE | None | 2 | ACTIVE, REVOKED |
| idp-identity-totp-enrollment | 4 | 8 | unverified, available | consumed, expired | None | None | 1 | consumed |
| idp-identity-secret-credential-candidate | 3 | 5 | available | consumed, expired | None | None | 1 | consumed |
| idp-identity-social-candidate | 3 | 5 | available | consumed, expired | None | None | 1 | consumed |
| idp-operator-organization-invitation | 3 | 2 | active | consumed, expired | None | None | 0 | None |
| idp-operator-operator-lifecycle | 5 | 3 | pending | rejected, executed, cancelled | cancelled | None | 0 | None |
| idp-shared-sequence-carrier | 5 | 20 | open, missing | None | None | missing | 2 | COMPLETED, EXPIRED, FAILED, open |
| idp-shared-authorization-code | 2 | 3 | issued | consumed | None | None | 1 | consumed |
| idp-shared-opaque-admission | 2 | 1 | issued | consumed | None | None | 0 | None |
| idp-client-secret-credential | 5 | 3 | candidate | revoked, discarded | claimed | claimed | 0 | None |
| idp-client-dpop-nonce | 2 | 1 | unused | used | None | None | 0 | None |
| idp-client-administrative-access | 2 | 4 | enabled | None | None | None | 1 | admin_locked, enabled |
| idp-client-email-verification-challenge | 4 | 3 | pending | verified, fallback, rejected | None | None | 0 | None |
| idp-client-preference-dbsc | 5 | 9 | NOTHING | None | FAILED, PENDING, REVOKE | None | 1 | ACTIVE |
| idp-client-email-otp | 3 | 6 | inactive | None | None | None | 1 | active |
| idp-client-telephone-otp | 3 | 6 | inactive | None | None | None | 1 | active |
| idp-visitor-secret-credential | 6 | 10 | ACTIVE | None | DELETED, NOTHING | None | 2 | ACTIVE, REVOKED |
| idp-visitor-dpop-nonce | 2 | 1 | unused | used | None | None | 0 | None |
| idp-visitor-administrative-access | 2 | 4 | enabled | None | None | None | 1 | admin_locked, enabled |
| idp-visitor-email-verification-challenge | 4 | 3 | pending | verified, fallback, rejected | None | None | 0 | None |
| idp-visitor-preference-dbsc | 5 | 9 | NOTHING | None | FAILED, PENDING, REVOKE | None | 1 | ACTIVE |
| idp-visitor-email-otp | 3 | 6 | inactive | None | None | None | 1 | active |
| idp-visitor-telephone-otp | 3 | 6 | inactive | None | None | None | 1 | active |
| idp-operator-secret-credential | 6 | 19 | ACTIVE | None | UNKNOWN_DEFAULT_0 | UNKNOWN_DEFAULT_0 | 1 | ACTIVE, DELETED, REVOKED |
| idp-operator-dpop-nonce | 2 | 1 | unused | used | None | None | 0 | None |
| idp-operator-administrative-access | 2 | 4 | enabled | None | None | None | 1 | admin_locked, enabled |
| idp-operator-email-verification-challenge | 4 | 3 | pending | verified, fallback, rejected | None | None | 0 | None |
| idp-operator-preference-dbsc | 5 | 9 | NOTHING | None | FAILED, PENDING, REVOKE | None | 1 | ACTIVE |
| idp-operator-email-otp | 3 | 6 | inactive | None | None | None | 1 | active |
| idp-operator-telephone-otp | 3 | 6 | inactive | None | None | None | 1 | active |
| idp-client-withdrawal | 7 | 8 | REQUESTED | RECOVERED, TERMINATED | NOTHING | FAILED | 0 | None |
| idp-visitor-withdrawal | 7 | 8 | REQUESTED | RECOVERED, TERMINATED | NOTHING | FAILED | 0 | None |
| idp-security-one-time-reveal | 2 | 1 | unused | consumed | None | None | 0 | None |
| idp-operator-entra-identity | 4 | 12 | NOTHING | None | None | None | 1 | ACTIVE, REVOKED, SUSPENDED |
| idp-client-step-up-session | 4 | 5 | PENDING | removed | VERIFIED | None | 1 | PENDING |
| idp-client-step-up-passkey-challenge | 4 | 6 | empty | None | None | None | 1 | issued |
| idp-client-step-up-email-challenge | 6 | 12 | empty | None | None | None | 1 | pending |
| idp-client-email-credential | 7 | 11 | UNVERIFIED, UNVERIFIED_WITH_SIGN_UP | None | NOTHING | None | 1 | SUSPENDED |
| idp-client-telephone-credential | 8 | 11 | UNVERIFIED, UNVERIFIED_WITH_SIGN_UP | None | LEGACY_NOTHING, NOTHING | None | 1 | SUSPENDED |
| idp-client-actor-withdrawal | 5 | 7 | active | None | closing, withdrawn | terminated, withdrawn | 1 | active, suspended |
| idp-visitor-step-up-session | 4 | 5 | PENDING | removed | VERIFIED | None | 1 | PENDING |
| idp-visitor-step-up-passkey-challenge | 4 | 6 | empty | None | None | None | 1 | issued |
| idp-visitor-step-up-email-challenge | 6 | 12 | empty | None | None | None | 1 | pending |
| idp-visitor-email-credential | 7 | 10 | UNVERIFIED, UNVERIFIED_WITH_SIGN_UP | None | NOTHING | None | 1 | SUSPENDED |
| idp-visitor-telephone-credential | 7 | 10 | UNVERIFIED, UNVERIFIED_WITH_SIGN_UP | None | NOTHING | None | 1 | SUSPENDED |
| idp-visitor-actor-withdrawal | 5 | 7 | active | None | closing, withdrawn | terminated, withdrawn | 1 | active, suspended |
| idp-operator-step-up-session | 4 | 5 | PENDING | removed | VERIFIED | None | 1 | PENDING |
| idp-operator-step-up-passkey-challenge | 4 | 6 | empty | None | None | None | 1 | issued |
| idp-operator-email-credential | 7 | 1 | UNVERIFIED | None | ACTIVE, DELETED, INACTIVE, NOTHING, PENDING | ACTIVE, DELETED, INACTIVE, NOTHING, PENDING, VERIFIED | 0 | None |
| idp-operator-telephone-credential | 7 | 1 | UNVERIFIED | None | ACTIVE, DELETED, INACTIVE, NOTHING, PENDING | ACTIVE, DELETED, INACTIVE, NOTHING, PENDING, VERIFIED | 0 | None |
| idp-operator-actor-withdrawal | 5 | 16 | active | None | closing, withdrawn | None | 1 | active, suspended, terminated |
| idp-client-actor-provisioning | 13 | 1 | UNVERIFIED_WITH_SIGN_UP, VERIFIED_WITH_SIGN_UP, NOTHING | None | ACTIVE, DELETED, GHOST, INACTIVE, PENDING, PENDING_DELETION, PRE_WITHDRAWAL_CONDITION, RESERVED, WITHDRAWAL_COMPLETED, WITHDRAWN | ACTIVE, DELETED, GHOST, INACTIVE, NOTHING, PENDING, PENDING_DELETION, PRE_WITHDRAWAL_CONDITION, RESERVED, VERIFIED_WITH_SIGN_UP, WITHDRAWAL_COMPLETED, WITHDRAWN | 0 | None |
| idp-shared-acme-logout | 5 | 10 | initiated | finalized | expired | None | 1 | in_progress |
| idp-shared-webauthn-challenge | 2 | 3 | issued | removed | None | None | 0 | None |
| idp-client-enforcement-case | 6 | 12 | draft, pending_approval | None | ended | None | 2 | active, closed |
| idp-client-enforcement-appeal | 5 | 9 | submitted | redacted | under_review | None | 1 | redacted |
| idp-visitor-enforcement-case | 6 | 12 | draft, pending_approval | None | ended | None | 2 | active, closed |
| idp-visitor-enforcement-appeal | 5 | 9 | submitted | redacted | under_review | None | 1 | redacted |
| idp-operator-enforcement-case | 6 | 12 | draft, pending_approval | None | ended | None | 2 | active, closed |
| idp-operator-enforcement-appeal | 5 | 9 | submitted | redacted | under_review | None | 1 | redacted |
| idp-shared-sign-out-notice | 2 | 2 | issued | absent | None | None | 0 | None |
| idp-client-mfa-readiness | 3 | 4 | UNCONFIGURED | None | NOTHING | None | 1 | None |
| idp-visitor-mfa-readiness | 3 | 4 | UNCONFIGURED | None | NOTHING | None | 1 | None |
| idp-operator-mfa-readiness | 3 | 4 | UNCONFIGURED | None | NOTHING | None | 1 | None |
| idp-client-email-registration-session | 3 | 12 | init | None | None | None | 1 | email_created, email_verified, init |
| idp-visitor-email-registration-session | 3 | 9 | init | None | None | None | 1 | email_created, email_verified, init |

## Candidate interpretation

- Token `rotated` and sequence-carrier `missing` sinks represent replacement/absence; these are not active-user lock-in conclusions.
- Withdrawal `FAILED` has no documented forward state edge and remains a genuine lifecycle review candidate; no fix is proposed.
- Timestamp-derived actor conditions can overlap. Their sink reachability cannot establish a finite exclusive lifecycle.
- Operator contact and client provisioning sinks include declared reference-only values whose ordinary writer/entry paths are UNKNOWN. A reference-only ACTIVE label is not evidence of a reachable active flow.
- Operator secret SQL default0 is an UNKNOWN reference value, not a proven active state. Its isolated node remains a source/data inconsistency candidate.

Source drift detected during the audit (see [README](./README.md)) prevents interpreting these results as final-checkout completeness.
