# WU-A2 App social callback generation shape

**Status: Proposed; owner shape and local migration approval required. No code or schema has been
changed for this proposal.**

## Contract

`two.md` §10.7 requires a new Google/Apple sign-up provider start to supersede the earlier state,
provider and nonce generation. An old callback must be refused after a provider restart, after an
Email/Telephone Flow exists, or after cancellation. The current App sign-up work handles sequential
restarts in one current cookie, but it does not persist the association between a callback attempt
and its Auth Ceremony, Admission Binding, OIDC parent, and generation. A callback made with a stale
signed-cookie snapshot can therefore race a different tab's provider restart.

The current generic `client_oauth_callback_states` table records only the provider, state digest,
optional intent, issue/expiry times, and nullable `consumed_at`. It does not identify a sign-up
attempt or its owning Auth state. The existing sequential restart behavior is recorded in
`evidence/2026-11-01-wua2-social-signup-back-restart-R7M4.md`; the missing cross-tab generation
association is recorded there as unimplemented.

## Proposed after shape

App OP Base only, for Google/Apple sign-up callback attempts:

| Table / column                                          | Type and constraint                                                             | Authority                                                         |
| ------------------------------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `client_social_signup_callback_generation_statuses.id`  | `smallint` primary key, NOT NULL                                                | fixed migration-seeded reference                                  |
| `client_social_signup_callback_generation_statuses.key` | `varchar(16)`, UNIQUE, NOT NULL                                                 | `issued`, `consumed`, `superseded`                                |
| `client_social_signup_callback_generations.id`          | `bigint` primary key, NOT NULL                                                  | database                                                          |
| `auth_ceremony_session_id`                              | `bigint`, NOT NULL, FK to `client_auth_ceremony_sessions.id`, RESTRICT          | current admitted Auth session                                     |
| `admission_binding_id`                                  | `bigint`, NOT NULL, FK to `client_auth_admission_bindings.id`, RESTRICT         | the exact redeemed sign-up binding                                |
| `authorization_transaction_id`                          | `bigint`, NOT NULL, FK to `client_oidc_authorization_transactions.id`, RESTRICT | the exact sign-up parent                                          |
| `generation`                                            | `bigint`, NOT NULL, CHECK `> 0`                                                 | monotonically increasing within the Auth Ceremony                 |
| `state_digest`                                          | `varchar(64)`, UNIQUE, NOT NULL                                                 | SHA-256 of the provider's OAuth state; raw state is not persisted |
| `provider`                                              | `varchar(16)`, NOT NULL, CHECK in `google`, `apple`                             | current provider start                                            |
| `status_id`                                             | `smallint`, NOT NULL, FK to the status reference                                | lifecycle of this callback attempt                                |
| `issued_at`, `expires_at`                               | `timestamptz`, NOT NULL                                                         | OP Base database clock; expiry remains five minutes               |

Unique indexes would enforce `(auth_ceremony_session_id, generation)` and at most one `issued`
generation per Auth Ceremony. The state row itself binds the exact parent, binding, provider,
ceremony, and generation; there is no `current_generation` nullable field or browser fingerprint.
There is no cross-database FK and no new Flow or account is created before a verified callback.

The App sign-up callback path would use this table as its one-time callback state store. Existing
generic callback-state records continue to cover App sign-in and credential-linking paths; no
sign-up fallback to those unbound records would remain. Starting a provider request locks and
revalidates the current Auth Ceremony, parent and binding, changes the prior `issued` attempt to
`superseded`, increments the generation, and inserts the new `issued` attempt in the same OP Base
transaction. Callback acceptance locks the same ownership rows in the §12.1 order, verifies the
state digest/provider/current browser session/parent/binding and current generation, then changes
`issued` to `consumed` before creating the sign-up Flow. A callback for a superseded generation is
refused without writing its stale session cookie back to the browser. Parent Cancel, Auth Ceremony
replacement and binding termination remain authoritative and independently reject the callback.

## Local data and migration impact

Read-only local inventory using the OP Base App database clock:

| Environment | Existing generic callback rows | Unconsumed | Unconsumed but unexpired | Unconsumed expired | Provider / intent grouping  |
| ----------- | -----------------------------: | ---------: | -----------------------: | -----------------: | --------------------------- |
| Development |                              0 |          0 |                        0 |                  0 | none                        |
| Test        |                              3 |          3 |                        0 |                  3 | Google / `intent = NULL`: 3 |

These are generic historical rows. The migration would not alter, delete, or infer sign-up ownership
for them. The new generation table begins empty; there is no backfill. Before local dev/test apply,
refresh full OP Base App database snapshots and record their hashes. No production, Neon or external
database operation is included.

The migration is additive. Its `down` path must raise if callback-generation rows exist, rather than
discarding provider-attempt history. Recovery from a failed local migration is full OP Base App
database restore from the recorded pre-migration snapshot; a rollback after callback rows are
created requires a fresh approved recovery plan. Applying this shape interrupts any in-flight
sign-up callback created before deployment, but no existing local row is currently unexpired.

## Focused verification after approval

- Sequential Google restart and Google-to-Apple restart: one current `issued` generation; old
  callback refused; Apple nonce remains tied to the current cookie generation.
- Two independent requests based on the same pre-restart signed cookie: both orders of provider
  start/callback; only the latest committed generation can advance a Flow.
- Cancel or Auth Ceremony replacement racing callback: the first committed owner transition wins;
  refused callback creates no Flow, credential, identity or audit success.
- Replay and cross-parent/cross-binding/cross-ceremony state: refused without mutation or stale
  session-cookie writeback; a valid current callback consumes the generation once.
- Database constraints reject missing owner IDs, unknown provider/status, duplicate state digest,
  duplicate per-ceremony generation and two simultaneous issued generations.

This shape is limited to WU-A2 App Google/Apple sign-up. It does not alter ORG Entra/invitation
registration or the generic App social sign-in/link flows.
