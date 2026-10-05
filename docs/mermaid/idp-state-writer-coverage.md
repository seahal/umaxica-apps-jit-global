# State writer coverage

The Ruby Prism scan parses every Ruby file under `app/`, `config/`, `lib/`, and `db/`. It records mutation APIs even when the state key is dynamic, state-bearing setter calls, and construction calls. This is a conservative **candidate** inventory: constructors, HTTP result objects, local hashes and unrelated domain updates are included until dispositioned. No tests were executed. Ruby source parsed with zero Prism errors.

`LINKED_BY_LOCAL_CALL_GRAPH` means a transition trigger names a method that reaches the writer through implicit-receiver/self calls in the same file and owner. It is **PARTIAL correspondence**, not proof of the guard, concrete receiver, written value, or all callers. Matching a file alone is never treated as covered. Dynamic dispatch, cross-file calls, SQL/Lua writes, callbacks, default initialization and metaprogramming remain manual obligations.

**Writer coverage is OPEN. Unmapped writers are not zero.** Do not use this extraction as proof that every state writer corresponds to the transition inventory. Each unresolved candidate has a stable site ID, file/line, owner/method, columns, expression SHA-256 and potential axes. Raw mutation expressions and credentials are not copied. The audit found separate email registration session states, cleanup dynamic status writes, and withdrawal secret revocation; those confirmed transitions have been added to CURRENT diagrams.

The complete site inventory was held in the removed `verification/` directory and is no longer available; the table below is the remaining record.

## Extraction dispositions

| Disposition | Sites |
| --- | --- |
| UNRESOLVED_REPO_CANDIDATE: scope/receiver/columns require review | 1098 |
| OUTCOME_OR_OBJECT_CONSTRUCTION | 312 |
| INITIALIZATION_CANDIDATE: entry/value mapping requires semantic review | 303 |
| UNMAPPED_STATE_WRITER_CANDIDATE | 140 |
| LINKED_BY_LOCAL_CALL_GRAPH | 169 |
| HASH_OR_PRESENTATION_ASSIGNMENT: receiver reviewed by extractor heuristic | 110 |
| VALUE_OR_QUERY_CONSTRUCTION: not proof of persisted write | 195 |
| SCHEMA_OR_REFERENCE_SEED: not a runtime transition | 57 |

## Per-axis correspondence

Counts refer to candidates with a potential axis, not a complete resolved receiver set. Unresolved repo candidates with no assigned axis remain in the full inventory.

| Axis | Potential sites | Linked by local calls | Unmapped / initialization sites | Linked transition IDs |
| --- | --- | --- | --- | --- |
| idp-client-sign-in | 63 | 0 | 63 | None |
| idp-client-sign-up | 21 | 3 | 18 | idp-client-sign-up:T040 |
| idp-client-sign-out | 4 | 0 | 4 | None |
| idp-client-auth-ceremony-session | 48 | 7 | 41 | idp-client-auth-ceremony-session:T001, idp-client-auth-ceremony-session:T002, idp-client-auth-ceremony-session:T003, idp-client-auth-ceremony-session:T004, idp-client-auth-ceremony-session:T005, idp-client-auth-ceremony-session:T006, idp-client-auth-ceremony-session:T007, idp-client-auth-ceremony-session:T008, idp-client-auth-ceremony-session:T009, idp-client-auth-ceremony-session:T010, idp-client-auth-ceremony-session:T011, idp-client-auth-ceremony-session:T012 |
| idp-client-email-ceremony | 7 | 1 | 6 | idp-client-email-ceremony:T001 |
| idp-client-telephone-ceremony | 7 | 1 | 6 | idp-client-telephone-ceremony:T001 |
| idp-client-passkey-ceremony | 6 | 1 | 5 | idp-client-passkey-ceremony:T001 |
| idp-client-secret-credential-ceremony | 6 | 1 | 5 | idp-client-secret-credential-ceremony:T001 |
| idp-client-step-up-ceremony | 42 | 17 | 25 | idp-client-step-up-ceremony:T001, idp-client-step-up-ceremony:T002, idp-client-step-up-ceremony:T005, idp-client-step-up-ceremony:T008, idp-client-step-up-ceremony:T010, idp-client-step-up-ceremony:T012, idp-client-step-up-ceremony:T013, idp-client-step-up-ceremony:T014, idp-client-step-up-ceremony:T015, idp-client-step-up-ceremony:T016 |
| idp-client-oidc-authorization | 12 | 3 | 9 | idp-client-oidc-authorization:T001, idp-client-oidc-authorization:T003, idp-client-oidc-authorization:T004 |
| idp-client-oauth-callback | 2 | 1 | 1 | idp-client-oauth-callback:T001 |
| idp-client-local-result-delivery | 4 | 1 | 3 | idp-client-local-result-delivery:T002, idp-client-local-result-delivery:T003 |
| idp-client-token | 50 | 14 | 36 | idp-client-token:T001, idp-client-token:T002, idp-client-token:T003, idp-client-token:T004, idp-client-token:T005, idp-client-token:T006, idp-client-token:T007, idp-client-token:T008, idp-client-token:T009, idp-client-token:T010, idp-client-token:T011, idp-client-token:T012, idp-client-token:T013, idp-client-token:T014, idp-client-token:T015, idp-client-token:T016, idp-client-token:T017 |
| idp-client-dbsc | 38 | 3 | 35 | idp-client-dbsc:T001, idp-client-dbsc:T002, idp-client-dbsc:T003, idp-client-dbsc:T004, idp-client-dbsc:T005, idp-client-dbsc:T006, idp-client-dbsc:T007, idp-client-dbsc:T008, idp-client-dbsc:T009 |
| idp-client-device-session | 14 | 13 | 1 | idp-client-device-session:T001, idp-client-device-session:T002, idp-client-device-session:T003, idp-client-device-session:T004 |
| idp-client-rp-session | 6 | 4 | 2 | idp-client-rp-session:T001, idp-client-rp-session:T002, idp-client-rp-session:T003 |
| idp-client-passkey-credential | 8 | 0 | 8 | None |
| idp-visitor-sign-in | 63 | 0 | 63 | None |
| idp-visitor-sign-up | 16 | 4 | 12 | idp-visitor-sign-up:T033 |
| idp-visitor-sign-out | 4 | 0 | 4 | None |
| idp-visitor-auth-ceremony-session | 48 | 7 | 41 | idp-visitor-auth-ceremony-session:T001, idp-visitor-auth-ceremony-session:T002, idp-visitor-auth-ceremony-session:T003, idp-visitor-auth-ceremony-session:T004, idp-visitor-auth-ceremony-session:T005, idp-visitor-auth-ceremony-session:T006, idp-visitor-auth-ceremony-session:T007, idp-visitor-auth-ceremony-session:T008, idp-visitor-auth-ceremony-session:T009, idp-visitor-auth-ceremony-session:T010, idp-visitor-auth-ceremony-session:T011, idp-visitor-auth-ceremony-session:T012 |
| idp-visitor-email-ceremony | 7 | 1 | 6 | idp-visitor-email-ceremony:T001 |
| idp-visitor-telephone-ceremony | 7 | 1 | 6 | idp-visitor-telephone-ceremony:T001 |
| idp-visitor-passkey-ceremony | 6 | 1 | 5 | idp-visitor-passkey-ceremony:T001 |
| idp-visitor-secret-credential-ceremony | 6 | 1 | 5 | idp-visitor-secret-credential-ceremony:T001 |
| idp-visitor-step-up-ceremony | 42 | 17 | 25 | idp-visitor-step-up-ceremony:T001, idp-visitor-step-up-ceremony:T002, idp-visitor-step-up-ceremony:T005, idp-visitor-step-up-ceremony:T008, idp-visitor-step-up-ceremony:T010, idp-visitor-step-up-ceremony:T012, idp-visitor-step-up-ceremony:T013, idp-visitor-step-up-ceremony:T014, idp-visitor-step-up-ceremony:T015, idp-visitor-step-up-ceremony:T016 |
| idp-visitor-oidc-authorization | 12 | 3 | 9 | idp-visitor-oidc-authorization:T001, idp-visitor-oidc-authorization:T003, idp-visitor-oidc-authorization:T004 |
| idp-visitor-local-result-delivery | 4 | 1 | 3 | idp-visitor-local-result-delivery:T002, idp-visitor-local-result-delivery:T003 |
| idp-visitor-token | 50 | 14 | 36 | idp-visitor-token:T001, idp-visitor-token:T002, idp-visitor-token:T003, idp-visitor-token:T004, idp-visitor-token:T005, idp-visitor-token:T006, idp-visitor-token:T007, idp-visitor-token:T008, idp-visitor-token:T009, idp-visitor-token:T010, idp-visitor-token:T011, idp-visitor-token:T012, idp-visitor-token:T013, idp-visitor-token:T014, idp-visitor-token:T015, idp-visitor-token:T016, idp-visitor-token:T017 |
| idp-visitor-dbsc | 38 | 3 | 35 | idp-visitor-dbsc:T001, idp-visitor-dbsc:T002, idp-visitor-dbsc:T003, idp-visitor-dbsc:T004, idp-visitor-dbsc:T005, idp-visitor-dbsc:T006, idp-visitor-dbsc:T007, idp-visitor-dbsc:T008, idp-visitor-dbsc:T009 |
| idp-visitor-device-session | 14 | 13 | 1 | idp-visitor-device-session:T001, idp-visitor-device-session:T002, idp-visitor-device-session:T003, idp-visitor-device-session:T004 |
| idp-visitor-rp-session | 6 | 4 | 2 | idp-visitor-rp-session:T001, idp-visitor-rp-session:T002, idp-visitor-rp-session:T003 |
| idp-visitor-passkey-credential | 8 | 0 | 8 | None |
| idp-operator-sign-in | 63 | 0 | 63 | None |
| idp-operator-sign-up | 9 | 0 | 9 | None |
| idp-operator-sign-out | 4 | 0 | 4 | None |
| idp-operator-auth-ceremony-session | 48 | 7 | 41 | idp-operator-auth-ceremony-session:T001, idp-operator-auth-ceremony-session:T002, idp-operator-auth-ceremony-session:T003, idp-operator-auth-ceremony-session:T004, idp-operator-auth-ceremony-session:T005, idp-operator-auth-ceremony-session:T006, idp-operator-auth-ceremony-session:T007, idp-operator-auth-ceremony-session:T008, idp-operator-auth-ceremony-session:T009, idp-operator-auth-ceremony-session:T010, idp-operator-auth-ceremony-session:T011, idp-operator-auth-ceremony-session:T012 |
| idp-operator-email-ceremony | 7 | 1 | 6 | idp-operator-email-ceremony:T001 |
| idp-operator-telephone-ceremony | 7 | 1 | 6 | idp-operator-telephone-ceremony:T001 |
| idp-operator-passkey-ceremony | 6 | 1 | 5 | idp-operator-passkey-ceremony:T001 |
| idp-operator-secret-credential-ceremony | 6 | 1 | 5 | idp-operator-secret-credential-ceremony:T001 |
| idp-operator-step-up-ceremony | 42 | 17 | 25 | idp-operator-step-up-ceremony:T001, idp-operator-step-up-ceremony:T002, idp-operator-step-up-ceremony:T005, idp-operator-step-up-ceremony:T008, idp-operator-step-up-ceremony:T010, idp-operator-step-up-ceremony:T012, idp-operator-step-up-ceremony:T013, idp-operator-step-up-ceremony:T014, idp-operator-step-up-ceremony:T015, idp-operator-step-up-ceremony:T016 |
| idp-operator-oidc-authorization | 12 | 3 | 9 | idp-operator-oidc-authorization:T001, idp-operator-oidc-authorization:T003, idp-operator-oidc-authorization:T004 |
| idp-operator-oauth-callback | 2 | 1 | 1 | idp-operator-oauth-callback:T001 |
| idp-operator-local-result-delivery | 4 | 1 | 3 | idp-operator-local-result-delivery:T002, idp-operator-local-result-delivery:T003 |
| idp-operator-token | 50 | 14 | 36 | idp-operator-token:T001, idp-operator-token:T002, idp-operator-token:T003, idp-operator-token:T004, idp-operator-token:T005, idp-operator-token:T006, idp-operator-token:T007, idp-operator-token:T008, idp-operator-token:T009, idp-operator-token:T010, idp-operator-token:T011, idp-operator-token:T012, idp-operator-token:T013, idp-operator-token:T014, idp-operator-token:T015, idp-operator-token:T016, idp-operator-token:T017 |
| idp-operator-dbsc | 38 | 3 | 35 | idp-operator-dbsc:T001, idp-operator-dbsc:T002, idp-operator-dbsc:T003, idp-operator-dbsc:T004, idp-operator-dbsc:T005, idp-operator-dbsc:T006, idp-operator-dbsc:T007, idp-operator-dbsc:T008, idp-operator-dbsc:T009 |
| idp-operator-device-session | 14 | 13 | 1 | idp-operator-device-session:T001, idp-operator-device-session:T002, idp-operator-device-session:T003, idp-operator-device-session:T004 |
| idp-operator-rp-session | 6 | 4 | 2 | idp-operator-rp-session:T001, idp-operator-rp-session:T002, idp-operator-rp-session:T003 |
| idp-operator-passkey-credential | 8 | 0 | 8 | None |
| idp-client-sign-up-cleanup | 13 | 7 | 6 | idp-client-sign-up-cleanup:T006, idp-client-sign-up-cleanup:T007, idp-client-sign-up-cleanup:T008 |
| idp-client-withdrawal-ceremony | 3 | 2 | 1 | idp-client-withdrawal-ceremony:T001, idp-client-withdrawal-ceremony:T002, idp-client-withdrawal-ceremony:T003, idp-client-withdrawal-ceremony:T004, idp-client-withdrawal-ceremony:T005, idp-client-withdrawal-ceremony:T006, idp-client-withdrawal-ceremony:T007, idp-client-withdrawal-ceremony:T008 |
| idp-client-enforcement-recovery-ceremony | 6 | 2 | 4 | idp-client-enforcement-recovery-ceremony:T001, idp-client-enforcement-recovery-ceremony:T002, idp-client-enforcement-recovery-ceremony:T003, idp-client-enforcement-recovery-ceremony:T004, idp-client-enforcement-recovery-ceremony:T005, idp-client-enforcement-recovery-ceremony:T006 |
| idp-visitor-sign-up-cleanup | 13 | 7 | 6 | idp-visitor-sign-up-cleanup:T006, idp-visitor-sign-up-cleanup:T007, idp-visitor-sign-up-cleanup:T008 |
| idp-visitor-withdrawal-ceremony | 3 | 2 | 1 | idp-visitor-withdrawal-ceremony:T001, idp-visitor-withdrawal-ceremony:T002, idp-visitor-withdrawal-ceremony:T003, idp-visitor-withdrawal-ceremony:T004, idp-visitor-withdrawal-ceremony:T005, idp-visitor-withdrawal-ceremony:T006, idp-visitor-withdrawal-ceremony:T007, idp-visitor-withdrawal-ceremony:T008 |
| idp-visitor-enforcement-recovery-ceremony | 6 | 2 | 4 | idp-visitor-enforcement-recovery-ceremony:T001, idp-visitor-enforcement-recovery-ceremony:T002, idp-visitor-enforcement-recovery-ceremony:T003, idp-visitor-enforcement-recovery-ceremony:T004, idp-visitor-enforcement-recovery-ceremony:T005, idp-visitor-enforcement-recovery-ceremony:T006 |
| idp-client-totp-ceremony | 4 | 1 | 3 | idp-client-totp-ceremony:T001 |
| idp-client-social-ceremony | 6 | 1 | 5 | idp-client-social-ceremony:T001 |
| idp-client-secret-issuance | 7 | 0 | 7 | None |
| idp-client-session-limit-resolution | 6 | 4 | 2 | idp-client-session-limit-resolution:T001, idp-client-session-limit-resolution:T002, idp-client-session-limit-resolution:T003, idp-client-session-limit-resolution:T004, idp-client-session-limit-resolution:T005, idp-client-session-limit-resolution:T006, idp-client-session-limit-resolution:T007, idp-client-session-limit-resolution:T008, idp-client-session-limit-resolution:T009, idp-client-session-limit-resolution:T010, idp-client-session-limit-resolution:T011, idp-client-session-limit-resolution:T012, idp-client-session-limit-resolution:T013, idp-client-session-limit-resolution:T014, idp-client-session-limit-resolution:T015 |
| idp-client-apple-notification | 9 | 0 | 9 | None |
| idp-client-external-identity | 6 | 1 | 5 | idp-client-external-identity:T005, idp-client-external-identity:T006 |
| idp-client-totp-credential | 6 | 1 | 5 | idp-client-totp-credential:T001, idp-client-totp-credential:T002 |
| idp-identity-totp-enrollment | 17 | 3 | 14 | idp-identity-totp-enrollment:T001, idp-identity-totp-enrollment:T002, idp-identity-totp-enrollment:T003, idp-identity-totp-enrollment:T004 |
| idp-identity-secret-credential-candidate | 11 | 3 | 8 | idp-identity-secret-credential-candidate:T001, idp-identity-secret-credential-candidate:T002, idp-identity-secret-credential-candidate:T003, idp-identity-secret-credential-candidate:T004 |
| idp-identity-social-candidate | 10 | 3 | 7 | idp-identity-social-candidate:T001, idp-identity-social-candidate:T002, idp-identity-social-candidate:T003, idp-identity-social-candidate:T004 |
| idp-operator-organization-invitation | 5 | 1 | 4 | idp-operator-organization-invitation:T001 |
| idp-operator-operator-lifecycle | 14 | 0 | 14 | None |
| idp-shared-sequence-carrier | 29 | 6 | 23 | idp-shared-sequence-carrier:T001, idp-shared-sequence-carrier:T002, idp-shared-sequence-carrier:T003, idp-shared-sequence-carrier:T005, idp-shared-sequence-carrier:T006, idp-shared-sequence-carrier:T007, idp-shared-sequence-carrier:T009, idp-shared-sequence-carrier:T010, idp-shared-sequence-carrier:T011, idp-shared-sequence-carrier:T013, idp-shared-sequence-carrier:T014, idp-shared-sequence-carrier:T015, idp-shared-sequence-carrier:T017, idp-shared-sequence-carrier:T018, idp-shared-sequence-carrier:T019, idp-shared-sequence-carrier:T020 |
| idp-shared-authorization-code | 3 | 0 | 3 | None |
| idp-shared-opaque-admission | 35 | 1 | 34 | idp-shared-opaque-admission:T001 |
| idp-client-secret-credential | 9 | 3 | 6 | idp-client-secret-credential:T001, idp-client-secret-credential:T002 |
| idp-client-dpop-nonce | 12 | 1 | 11 | idp-client-dpop-nonce:T001 |
| idp-client-administrative-access | 6 | 5 | 1 | idp-client-administrative-access:T001, idp-client-administrative-access:T002, idp-client-administrative-access:T003, idp-client-administrative-access:T004 |
| idp-client-email-verification-challenge | 6 | 1 | 5 | idp-client-email-verification-challenge:T001, idp-client-email-verification-challenge:T002, idp-client-email-verification-challenge:T003 |
| idp-client-preference-dbsc | 5 | 3 | 2 | idp-client-preference-dbsc:T001, idp-client-preference-dbsc:T002, idp-client-preference-dbsc:T003, idp-client-preference-dbsc:T004, idp-client-preference-dbsc:T005, idp-client-preference-dbsc:T006, idp-client-preference-dbsc:T007, idp-client-preference-dbsc:T008, idp-client-preference-dbsc:T009 |
| idp-client-email-otp | 36 | 10 | 26 | idp-client-email-otp:T001, idp-client-email-otp:T002, idp-client-email-otp:T003, idp-client-email-otp:T005, idp-client-email-otp:T006 |
| idp-client-telephone-otp | 37 | 10 | 27 | idp-client-telephone-otp:T001, idp-client-telephone-otp:T002, idp-client-telephone-otp:T003, idp-client-telephone-otp:T005, idp-client-telephone-otp:T006 |
| idp-visitor-secret-credential | 15 | 3 | 12 | idp-visitor-secret-credential:T001, idp-visitor-secret-credential:T003 |
| idp-visitor-dpop-nonce | 12 | 1 | 11 | idp-visitor-dpop-nonce:T001 |
| idp-visitor-administrative-access | 5 | 5 | 0 | idp-visitor-administrative-access:T001, idp-visitor-administrative-access:T002, idp-visitor-administrative-access:T003, idp-visitor-administrative-access:T004 |
| idp-visitor-email-verification-challenge | 6 | 1 | 5 | idp-visitor-email-verification-challenge:T001, idp-visitor-email-verification-challenge:T002, idp-visitor-email-verification-challenge:T003 |
| idp-visitor-preference-dbsc | 5 | 3 | 2 | idp-visitor-preference-dbsc:T001, idp-visitor-preference-dbsc:T002, idp-visitor-preference-dbsc:T003, idp-visitor-preference-dbsc:T004, idp-visitor-preference-dbsc:T005, idp-visitor-preference-dbsc:T006, idp-visitor-preference-dbsc:T007, idp-visitor-preference-dbsc:T008, idp-visitor-preference-dbsc:T009 |
| idp-visitor-email-otp | 39 | 14 | 25 | idp-visitor-email-otp:T001, idp-visitor-email-otp:T002, idp-visitor-email-otp:T003, idp-visitor-email-otp:T005, idp-visitor-email-otp:T006 |
| idp-visitor-telephone-otp | 37 | 10 | 27 | idp-visitor-telephone-otp:T001, idp-visitor-telephone-otp:T002, idp-visitor-telephone-otp:T003, idp-visitor-telephone-otp:T005, idp-visitor-telephone-otp:T006 |
| idp-operator-secret-credential | 16 | 3 | 13 | idp-operator-secret-credential:T001, idp-operator-secret-credential:T018 |
| idp-operator-dpop-nonce | 12 | 1 | 11 | idp-operator-dpop-nonce:T001 |
| idp-operator-administrative-access | 6 | 5 | 1 | idp-operator-administrative-access:T001, idp-operator-administrative-access:T002, idp-operator-administrative-access:T003, idp-operator-administrative-access:T004 |
| idp-operator-email-verification-challenge | 6 | 1 | 5 | idp-operator-email-verification-challenge:T001, idp-operator-email-verification-challenge:T002, idp-operator-email-verification-challenge:T003 |
| idp-operator-preference-dbsc | 5 | 3 | 2 | idp-operator-preference-dbsc:T001, idp-operator-preference-dbsc:T002, idp-operator-preference-dbsc:T003, idp-operator-preference-dbsc:T004, idp-operator-preference-dbsc:T005, idp-operator-preference-dbsc:T006, idp-operator-preference-dbsc:T007, idp-operator-preference-dbsc:T008, idp-operator-preference-dbsc:T009 |
| idp-operator-email-otp | 25 | 10 | 15 | idp-operator-email-otp:T001, idp-operator-email-otp:T002, idp-operator-email-otp:T003, idp-operator-email-otp:T005, idp-operator-email-otp:T006 |
| idp-operator-telephone-otp | 28 | 10 | 18 | idp-operator-telephone-otp:T001, idp-operator-telephone-otp:T002, idp-operator-telephone-otp:T003, idp-operator-telephone-otp:T005, idp-operator-telephone-otp:T006 |
| idp-client-withdrawal | 7 | 5 | 2 | idp-client-withdrawal:T001, idp-client-withdrawal:T002, idp-client-withdrawal:T003, idp-client-withdrawal:T004, idp-client-withdrawal:T005, idp-client-withdrawal:T006, idp-client-withdrawal:T007, idp-client-withdrawal:T008 |
| idp-visitor-withdrawal | 7 | 5 | 2 | idp-visitor-withdrawal:T001, idp-visitor-withdrawal:T002, idp-visitor-withdrawal:T003, idp-visitor-withdrawal:T004, idp-visitor-withdrawal:T005, idp-visitor-withdrawal:T006, idp-visitor-withdrawal:T007, idp-visitor-withdrawal:T008 |
| idp-security-one-time-reveal | 13 | 1 | 12 | idp-security-one-time-reveal:T001 |
| idp-operator-entra-identity | 7 | 0 | 7 | None |
| idp-client-step-up-session | 21 | 1 | 20 | None |
| idp-client-step-up-passkey-challenge | 4 | 3 | 1 | idp-client-step-up-passkey-challenge:T001, idp-client-step-up-passkey-challenge:T002, idp-client-step-up-passkey-challenge:T003, idp-client-step-up-passkey-challenge:T004, idp-client-step-up-passkey-challenge:T006 |
| idp-client-step-up-email-challenge | 7 | 3 | 4 | idp-client-step-up-email-challenge:T001, idp-client-step-up-email-challenge:T002, idp-client-step-up-email-challenge:T003, idp-client-step-up-email-challenge:T004, idp-client-step-up-email-challenge:T005, idp-client-step-up-email-challenge:T006, idp-client-step-up-email-challenge:T007, idp-client-step-up-email-challenge:T008, idp-client-step-up-email-challenge:T009 |
| idp-client-email-credential | 20 | 0 | 20 | None |
| idp-client-telephone-credential | 20 | 0 | 20 | None |
| idp-client-actor-withdrawal | 8 | 6 | 2 | idp-client-actor-withdrawal:T002, idp-client-actor-withdrawal:T003, idp-client-actor-withdrawal:T004, idp-client-actor-withdrawal:T005, idp-client-actor-withdrawal:T006 |
| idp-visitor-step-up-session | 21 | 1 | 20 | None |
| idp-visitor-step-up-passkey-challenge | 4 | 3 | 1 | idp-visitor-step-up-passkey-challenge:T001, idp-visitor-step-up-passkey-challenge:T002, idp-visitor-step-up-passkey-challenge:T003, idp-visitor-step-up-passkey-challenge:T004, idp-visitor-step-up-passkey-challenge:T006 |
| idp-visitor-step-up-email-challenge | 7 | 3 | 4 | idp-visitor-step-up-email-challenge:T001, idp-visitor-step-up-email-challenge:T002, idp-visitor-step-up-email-challenge:T003, idp-visitor-step-up-email-challenge:T004, idp-visitor-step-up-email-challenge:T005, idp-visitor-step-up-email-challenge:T006, idp-visitor-step-up-email-challenge:T007, idp-visitor-step-up-email-challenge:T008, idp-visitor-step-up-email-challenge:T009 |
| idp-visitor-email-credential | 23 | 4 | 19 | None |
| idp-visitor-telephone-credential | 20 | 0 | 20 | None |
| idp-visitor-actor-withdrawal | 7 | 6 | 1 | idp-visitor-actor-withdrawal:T002, idp-visitor-actor-withdrawal:T003, idp-visitor-actor-withdrawal:T004, idp-visitor-actor-withdrawal:T005, idp-visitor-actor-withdrawal:T006 |
| idp-operator-step-up-session | 21 | 1 | 20 | None |
| idp-operator-step-up-passkey-challenge | 4 | 3 | 1 | idp-operator-step-up-passkey-challenge:T001, idp-operator-step-up-passkey-challenge:T002, idp-operator-step-up-passkey-challenge:T003, idp-operator-step-up-passkey-challenge:T004, idp-operator-step-up-passkey-challenge:T006 |
| idp-operator-email-credential | 9 | 0 | 9 | None |
| idp-operator-telephone-credential | 11 | 0 | 11 | None |
| idp-operator-actor-withdrawal | 8 | 0 | 8 | None |
| idp-client-actor-provisioning | 22 | 0 | 22 | None |
| idp-shared-acme-logout | 17 | 2 | 15 | idp-shared-acme-logout:T004, idp-shared-acme-logout:T005, idp-shared-acme-logout:T006, idp-shared-acme-logout:T007, idp-shared-acme-logout:T008, idp-shared-acme-logout:T009, idp-shared-acme-logout:T010 |
| idp-shared-webauthn-challenge | 3 | 3 | 0 | idp-shared-webauthn-challenge:T001, idp-shared-webauthn-challenge:T002, idp-shared-webauthn-challenge:T003 |
| idp-client-enforcement-case | 18 | 0 | 18 | None |
| idp-client-enforcement-appeal | 5 | 3 | 2 | idp-client-enforcement-appeal:T001, idp-client-enforcement-appeal:T002, idp-client-enforcement-appeal:T003, idp-client-enforcement-appeal:T004, idp-client-enforcement-appeal:T005, idp-client-enforcement-appeal:T006, idp-client-enforcement-appeal:T007, idp-client-enforcement-appeal:T008, idp-client-enforcement-appeal:T009 |
| idp-visitor-enforcement-case | 18 | 0 | 18 | None |
| idp-visitor-enforcement-appeal | 5 | 3 | 2 | idp-visitor-enforcement-appeal:T001, idp-visitor-enforcement-appeal:T002, idp-visitor-enforcement-appeal:T003, idp-visitor-enforcement-appeal:T004, idp-visitor-enforcement-appeal:T005, idp-visitor-enforcement-appeal:T006, idp-visitor-enforcement-appeal:T007, idp-visitor-enforcement-appeal:T008, idp-visitor-enforcement-appeal:T009 |
| idp-operator-enforcement-case | 18 | 0 | 18 | None |
| idp-operator-enforcement-appeal | 5 | 3 | 2 | idp-operator-enforcement-appeal:T001, idp-operator-enforcement-appeal:T002, idp-operator-enforcement-appeal:T003, idp-operator-enforcement-appeal:T004, idp-operator-enforcement-appeal:T005, idp-operator-enforcement-appeal:T006, idp-operator-enforcement-appeal:T007, idp-operator-enforcement-appeal:T008, idp-operator-enforcement-appeal:T009 |
| idp-shared-sign-out-notice | 4 | 0 | 4 | None |
| idp-client-mfa-readiness | 9 | 2 | 7 | idp-client-mfa-readiness:T001, idp-client-mfa-readiness:T002, idp-client-mfa-readiness:T003, idp-client-mfa-readiness:T004 |
| idp-visitor-mfa-readiness | 7 | 2 | 5 | idp-visitor-mfa-readiness:T001, idp-visitor-mfa-readiness:T002, idp-visitor-mfa-readiness:T003, idp-visitor-mfa-readiness:T004 |
| idp-operator-mfa-readiness | 8 | 2 | 6 | idp-operator-mfa-readiness:T001, idp-operator-mfa-readiness:T002, idp-operator-mfa-readiness:T003, idp-operator-mfa-readiness:T004 |
| idp-client-email-registration-session | 17 | 2 | 15 | idp-client-email-registration-session:T001, idp-client-email-registration-session:T002, idp-client-email-registration-session:T003, idp-client-email-registration-session:T004, idp-client-email-registration-session:T005, idp-client-email-registration-session:T006, idp-client-email-registration-session:T007, idp-client-email-registration-session:T008, idp-client-email-registration-session:T009, idp-client-email-registration-session:T010, idp-client-email-registration-session:T011, idp-client-email-registration-session:T012 |
| idp-visitor-email-registration-session | 15 | 9 | 6 | idp-visitor-email-registration-session:T001, idp-visitor-email-registration-session:T002, idp-visitor-email-registration-session:T003, idp-visitor-email-registration-session:T004, idp-visitor-email-registration-session:T005, idp-visitor-email-registration-session:T006, idp-visitor-email-registration-session:T007, idp-visitor-email-registration-session:T008, idp-visitor-email-registration-session:T009 |
