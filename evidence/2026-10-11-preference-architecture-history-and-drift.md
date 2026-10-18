# Preference Architecture History and Drift Investigation

**Investigation date:** 2026-10-11

**Repository:** `seahal/umaxica-apps-jit-global`

**Local HEAD:** `d74e674d21e21207af02a086a9abbfe0104ab436`

**Scope:** Documentation-only architectural history and source audit, not a penetration test,
ASVS conformity assessment, deployment verification or runtime test result.

## Basis, provenance and limitations

The local worktree is authoritative. It was already dirty, including `adr/README.md`, the source-policy
rule, and Client/Operator/VisitorPreference public-id generation changes (Nanoid to PublicId), plus
unrelated controllers, schemas and tests. Those existing changes were inspected where relevant and
preserved. Source findings below describe this worktree over HEAD, not GitHub Global feature.
No application implementation, configuration, schema or test was changed by this task.

The requested exact evidence filename is retained under the user's explicit instruction, overriding
the usual four-character evidence suffix convention. Only this evidence and the companion
[Proposed ADR](../adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md) are task-authored files.
Existing Accepted records were not edited.

Facts come from current source, test assertions inspected, `git log --follow`, pickaxe searches,
`git show`/diff inspection, and read-only Edge references. Generic checkpoint titles were not treated
as intent. Timeline dates are Git author calendar dates; documentary dates and commit dates differ.
Abbreviated revisions elsewhere are unambiguous in the inspected history; timeline links provide full SHAs.

No Rails, Vitest, real-browser, DB-failure injection, production cache or deployment test was executed.
“Implemented” below means source-confirmed behavior, with existing test coverage identified where
available; it does not mean those tests passed in this session. Risk implications from source tracing
are explicitly labeled assessment. No secret values were inspected. Physical secret provisioning,
actual historical DB application and newer unpushed Edge changes are Unverified.

## Classification

| Class | Meaning in this record |
| --- | --- |
| Implemented | Present in inspected code; related assertions are evidence of test intent, not a current execution result. |
| Accepted | A current accepted decision in the owning ADR, accounting for scoped amendments. |
| Superseded | A contract explicitly replaced by a later decision; unaffected portions can survive. |
| Historical | Earlier code or policy no longer governing; repository presence does not prove deployment. |
| Proposed | A candidate in the October 11 discussion/companion ADR, without implementation authorization. |
| Open | A design judgment still required. |
| Drift | A concrete mismatch among ADR, docs, implementation, tests or historical claims. |
| Unverified | Insufficient artifacts or no runtime/external evidence. |

Designer statements and engineering assessment are not promoted to Git facts by this classification.

## Chronology from inspected diffs

| Date | Commit | Class | Relevant paths at that revision | Observed change |
| --- | --- | --- | --- | --- |
| 2025-12-22 | [`d7ca4492d4044b0610f3a676f3f526ee9df3c726`](https://github.com/seahal/umaxica-apps-jit-global/commit/d7ca4492d4044b0610f3a676f3f526ee9df3c726) | Historical | `app/controllers/concerns/preference_cookie.rb`, `app/services/preference_token.rb`, `config/initializers/preference_jwt.rb` | Signed HttpOnly permanent Preference cookie, a one-year ES256 JWT and legacy signed-JSON reader existed before the later access/refresh pair. This is the earliest prototype inspected, not proof of the first-ever Preference requirement. |
| 2026-01-07 | [`25ee7819169e77dcdace15cc08077602e5021f65`](https://github.com/seahal/umaxica-apps-jit-global/commit/25ee7819169e77dcdace15cc08077602e5021f65) | Historical | `app/models/{app,com,org}_preference.rb` and related option/child/audit migrations | Added DB-backed surface families with public references, expiry/digest and cookie/region/timezone/language/color-theme children. DB state allowed anonymous settings independently of an authenticated principal. Existing prototype code also remained temporarily. |
| 2026-01-14 | [`bcbb893164457f38681ef2942bbb546917484173`](https://github.com/seahal/umaxica-apps-jit-global/commit/bcbb893164457f38681ef2942bbb546917484173) | Historical | `app/controllers/concerns/preference/{base,token,jwt_configuration}.rb` | Added the dedicated seven-day ES256 access JWT and 400-day refresh design. Access carries a DB projection and Preference public_id/type. Reissue extended refresh lifetime; this was not yet the later replacement-row single-use rotation. These paths had no GET/HEAD separation. |
| 2026-02-16 | [`e90cded94462e209764c4f9467bb4e17a194b80b`](https://github.com/seahal/umaxica-apps-jit-global/commit/e90cded94462e209764c4f9467bb4e17a194b80b) | Historical | `app/models/concerns/consume_once_token.rb`, `db/preferences_migrate/20260216130000_add_consume_once_fields_to_preferences.rb`, old `preference/base.rb` | Added consume-once fields, replacement rows, fresh jti/public_id/verifier, child migration and replay/revocation predicates; controller reissue uses the rotated row. The diff, rather than the generic commit title, establishes rotation/replay machinery. |
| 2026-03-12 | [`fb29a1dace0bb76aa7ca2c600ee150cebf5710a2`](https://github.com/seahal/umaxica-apps-jit-global/commit/fb29a1dace0bb76aa7ca2c600ee150cebf5710a2) | Historical | old `preference/base.rb`, `db/preferences_migrate/20260312021828_create_preference_binding_methods_and_dbsc_statuses.rb`, `app/services/dbsc/*` | Added Preference binding/status metadata, DBSC registration/verification infrastructure and key-id/type validation. Auth tokens and Preference records share DBSC-capable abstractions; this demonstrates reuse, not the designer's original motivation. |
| 2026-03-23 | [`fab2504204cfe16557c6f85b7c5e12f844a78641`](https://github.com/seahal/umaxica-apps-jit-global/commit/fab2504204cfe16557c6f85b7c5e12f844a78641) | Historical | `app/models/current/preference.rb` (followed into `app/models/actor/preference.rb`) | Added the immutable Current::Preference read value, with NULL and cookie state. Actor consolidation was later; the renamed file path would obscure this antecedent without --follow. |
| 2026-03-29 | [`1f5f7582ef90c40dfc99e7916144c789d1d9abdc`](https://github.com/seahal/umaxica-apps-jit-global/commit/1f5f7582ef90c40dfc99e7916144c789d1d9abdc) | Historical | old `preference/base.rb`, `app/controllers/concerns/preference/dbsc_registration_endpoint.rb`, `app/services/dbsc/registration_service.rb` | DBSC hardening included expiring challenges, structured header tokens, no public_id fallback for incomplete binding and a separate Preference registration adapter. No evidence establishes browser deployment/adoption. |
| 2026-04-07 | [`66b81dd9a1bec458d4b2b43413bba202bf9efc86`](https://github.com/seahal/umaxica-apps-jit-global/commit/66b81dd9a1bec458d4b2b43413bba202bf9efc86) | Historical | `db/settings_migrate/20260407000001_create_unified_preferences_in_setting_db.rb` | A unified settings_preferences migration with owner_type/owner_id and related tables was committed. This contradicts later categorical claims that no such implementation ever existed; production application remains Unverified. |
| 2026-04-15 | [`3a62765a2e22f0d00adaf1050d1328ea8b568da1`](https://github.com/seahal/umaxica-apps-jit-global/commit/3a62765a2e22f0d00adaf1050d1328ea8b568da1) | Historical | `app/models/setting_preference.rb` and `app/controllers/concerns/preference/storage_adapter.rb` | Committed unified model/storage-adapter implementation is visible in history. Current absence is not evidence of historical nonexistence. |
| 2026-04-25 | [`95d7a5460561206d43415d940edc26d09be6701f`](https://github.com/seahal/umaxica-apps-jit-global/commit/95d7a5460561206d43415d940edc26d09be6701f) | Historical | `app/models/setting_preference.rb`, old unified migration/storage paths | Removed unified implementation during engine-era restructuring. The May doctrine later explicitly rejects all-surface DB consolidation and adapter dual-read/dual-write; the exact deployment history cannot be reconstructed from repository files alone. |
| 2026-05-15 | [`97b0241aba47bceee28ea08e218d7120be97b50b`](https://github.com/seahal/umaxica-apps-jit-global/commit/97b0241aba47bceee28ea08e218d7120be97b50b) | Accepted / Historical | `adr/actor-current-facade.md`, `adr/preference-relogin-reconciliation-record-recency.md`, Preference concerns | Committed ADRs dated May 13 (Actor) and May 10 (whole-record recency). Record the ADR date separately from Git availability. This commit still has the singular Actor.preference facade. |
| 2026-05-20 | [`1b39753a00ead0cabe1f9ccc2f81713471e96aef`](https://github.com/seahal/umaxica-apps-jit-global/commit/1b39753a00ead0cabe1f9ccc2f81713471e96aef) | Implemented / Historical | `app/models/{app,com,org}_setting_record.rb`, `db/{app,com,org}_settings_migrate/20260518030000_load_initial_*_setting_schema.rb`, old `preference/transport.rb` | Introduced explicit setting connection classes for the three independent families, matching the May 18 placement amendment. Also extracted transport orchestration and bounded authenticated HTML edit-entry DB-to-JWT refresh. |
| 2026-05-25 | [`0b659205190d76f581c8e933bc73f187257e35a7`](https://github.com/seahal/umaxica-apps-jit-global/commit/0b659205190d76f581c8e933bc73f187257e35a7) | Implemented | `app/models/actor.rb` | Renamed the facade/context member from preference to preferences; current consumers retain Actor.preferences. |
| 2026-05-30 | [`aa017d662952dd776a3d053b4bc617771b6e941d`](https://github.com/seahal/umaxica-apps-jit-global/commit/aa017d662952dd776a3d053b4bc617771b6e941d) | Implemented / Superseded | `app/controllers/concerns/actor_support.rb`, `adr/actor-current-facade.md` hydration amendment | Replaced auth-token prf hydration with dedicated Preference JWT preferences; introduced explicit-language handling for region seeding. The discarded prf snapshot did not represent authoritative DB preferences, as the contemporary comment/docs explain. |
| 2026-06-18 | [`822dbfbd6e1a210496d06b28607d61f04dccbe37`](https://github.com/seahal/umaxica-apps-jit-global/commit/822dbfbd6e1a210496d06b28607d61f04dccbe37) | Implemented / Historical | `app/controllers/concerns/preference_{base,cookie_name,io_keys}.rb`, `adr/cookie-domain-scope-by-surface.md` | Set domain:false and Path=/ for credential writes; adopted role-only host-prefixed names and scoped/__Secure legacy read/delete lists. DB/surface isolation and browser slot names became distinct responsibilities. Mirror sharing was subsequently restored explicitly. |
| 2026-06-29 | [`bdb2f5f6a4c689b3da195298e9c84aebf432758a`](https://github.com/seahal/umaxica-apps-jit-global/commit/bdb2f5f6a4c689b3da195298e9c84aebf432758a) | Implemented | `app/controllers/concerns/preference_cookie_writer.rb` | Explicit domain:true for non-HttpOnly public mirrors. Host-only credential isolation and domain-scoped display compatibility therefore coexist deliberately, not as identical cookie categories. |
| 2026-07-21 | [`6cbba7e60a43e9a2a9984f60fd0a11696d5a5c0f`](https://github.com/seahal/umaxica-apps-jit-global/commit/6cbba7e60a43e9a2a9984f60fd0a11696d5a5c0f) | Implemented / Drift | `preference_adoption.rb`, `preference_sign_out_rotation.rb`, `preference_access_token_transport.rb`, three explicit_fields migrations | Added per-key explicit-intent reconciliation, fresh guest identity/safe-copy on sign-out and retirement checks on ordinary DB access lookup (active.unconsumed). Current July 21 research and behavior docs explain the target; the May recency ADR was not amended/superseded. |
| 2026-07-22 | [`c41e66ed0297b28997d6d573d4d54a3ddc682999`](https://github.com/seahal/umaxica-apps-jit-global/commit/c41e66ed0297b28997d6d573d4d54a3ddc682999) | Implemented | `preference_sign_out_rotation.rb`, `preference_refresh_token_transport.rb` | Separated new-row persistence from cookie issuance and used one transaction for guest creation/seed/old-row retirement. Current code retains this distinction; cookies cannot roll back with DB. |
| 2026-08-27 | [`8b3d9bae64afa0057a8bf0e27614a29841653294`](https://github.com/seahal/umaxica-apps-jit-global/commit/8b3d9bae64afa0057a8bf0e27614a29841653294) | Historical | `preference_base.rb`, token/retention concerns | Adjusted expiry readers toward retention-column vocabulary. Current models later alias expires_at to discard_at; never treat the old field spelling as a separate current expiry authority. |
| 2026-09-25 | [`47312b92081a6a88a8ec1d27d3786d1a10063ce2`](https://github.com/seahal/umaxica-apps-jit-global/commit/47312b92081a6a88a8ec1d27d3786d1a10063ce2) | Implemented | `preference_transport.rb`, `preference_refresh_token_transport.rb`, DB write allowlist | Added GET/HEAD early return with read-only access/refresh-record lookup. Ordinary navigation no longer bootstraps, rotates or reissues. This is distinct from the May auth transparent-refresh gate, which at that time allowed HTML GET/HEAD. |
| 2026-09-29 | [`f8c93e4a9a50e22a942976a5810962f039662206`](https://github.com/seahal/umaxica-apps-jit-global/commit/f8c93e4a9a50e22a942976a5810962f039662206) | Implemented | `preference_transport.rb`, `preference_refresh_token_transport.rb`, `adr/invalid-browser-credential-recovery.md` | Committed the September 26 recovery ADR, confirmed-cause taxonomy, stale-generation read handling and removal of the HTML edit-entry reissue helper. Invalid reads detach; unexplained/system failures raise. |
| 2026-10-02 | [`b7c56bbf0f87c9a71440abc363a7bb4682f90839`](https://github.com/seahal/umaxica-apps-jit-global/commit/b7c56bbf0f87c9a71440abc363a7bb4682f90839) | Accepted / Implemented | `adr/preference-browser-transport-family-capability.md`, browser API/controllers/registry, `src/lib/request.ts` | Implemented host-local /api/v0/preferences/{theme,cookie} for Base/Auth/Core/Warp. Family capability fixes Palm 404 controls, server declares paths, browser enforces same-origin. ADR says lifecycle is unchanged; specialized API drift below predates or survives this transport cleanup. |
| 2026-10-04 | [`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`](https://github.com/seahal/umaxica-apps-jit-global/commit/f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5) | Accepted | `adr/tanstack-start-zero-cookie-ui-origin-boundary.md` | Recorded TanStack/Core cookie stripping, no credential-based SSR personalization and non-issuing auth/feel GET reads. feel names in prose are not current cookie constants. |
| 2026-10-09 | [`2854ee6967f3bd9e4c3faef1976f30fcb4816d33`](https://github.com/seahal/umaxica-apps-jit-global/commit/2854ee6967f3bd9e4c3faef1976f30fcb4816d33) | Historical | knowledge-directory moves and `docs/architecture/preference-behavior-contract.md` references | Folded memos/notes/plan analysis into research and introduced specs/checklists. A few Preference references still point to nonexistent research/implementation destinations; discovery must follow the actual moved files. |

### Historical requirements and rejected directions

**Historical facts:** the December prototype exposed language/region/theme-related settings without
account authority; January added DB-backed anonymous surface families and option/audit storage.
The dedicated access JWT made settings available as a signed projection while refresh/write flows
retained durable DB state. March Current::Preference, the May Actor facade and May 30 hydration
change insulated application reads from storage and removed the inaccurate auth `prf` channel.
These code changes substantiate display/runtime separation; they do not prove the original author's
full requirements or auth-PoC motivation.

**Recorded rationale:** [soft bubbles](../adr/preference-soft-bubble-doctrine.md) reject merging all
Preference DBs and replacing surface roots with JWT-only state: separate bubbles bound coordinated
change/blast radius, and anonymous state must exist independently of an account. Actor-local state
is retained for account persistence across browsers. Login adoption is an explicit synchronization
boundary, not a cross-domain shared row or atomic transaction across DBs. Current storage uses
App/Com/OrgSettingRecord and Client/Operator/VisitorPreference through matching PrincipalRecord
bases; [global DB ownership](../adr/global-regional-database-ownership.md) and principal-to-zenith
placement distinguish logical ownership from historical physical database names.

**Withdrawn/rejected proposals:** [GH-628 archive](../plans/archive/gh628-move-preferences-to-setting-db.md)
records the unified `setting` direction and adapter removal. The archived
[Customer move](../plans/archive/customer-preferences-move-to-com-preference-db.md) would have moved
actor-local Com state into the shared Preference DB; its current banner rejects that target in
favor of setting/principal separation. The archived
[Staff move](../plans/archive/staff-preference-move-to-operator-db.md) is likewise historical.
These are not instructions to consolidate, migrate or revive adapters.

**Historical-claim drift:** the soft-bubble context and
[withdrawn polymorphic-owner ADR](../adr/setting-preference-remove-polymorphic-owner.md) state the
unified polymorphic table was never implemented. The April 7 migration expressly creates it, the
April 15 model exists, and the April 25 diff deletes that model. This proves implementation artifacts
existed, not that a production table ever existed. Treat “never implemented” as contradicted at
repository level; deployed persistence history is Unverified. The archive's early “runtime cutover
done” and later rejected-target banners must likewise not be collapsed into a single current state.

**Open/debt:** [explicit-only child Model A](../plans/backlog/preference-explicit-child-records-model-a.md)
would replace eager defaults plus explicit_fields with child absence; it is not implemented or part
of this redesign authorization. Current per-key reconciliation uses child timestamps as best-effort
recency, not strict causality. Shared/actor-local writes span separate DBs, so failure/recovery and
incomplete convergence remain a real design boundary. No new schema/merge decision is made here.

## Accepted decisions against current implementation

| Decision / source | Current code or inspected tests | Classification and judgment |
| --- | --- | --- |
| [Soft bubbles](../adr/preference-soft-bubble-doctrine.md) and [Actor facade](../adr/actor-current-facade.md) | `app/models/{app,com,org}_preference.rb`, `app/models/actor/preference.rb`, `actor_support.rb`, `preference_class_registry.rb` | Implemented separation/facade. Sign/IdP ownership and auth-prf hydration are Superseded portions, not current implementation instructions. Normal GET DB lookup conflicts with no-extra-DB prose (D4). |
| [Preference scope](../adr/preference-scope-and-browser-persistent-state-separation.md) | `PreferenceClassRegistry::CHILD_RECORD_TYPES`, display resolver, sign-out safe-copy | Accepted display/usage boundary and reserved continuity. JWT contains Preference reference, not account identity. Adult gate remains display reflection, never age proof. ADR index incorrectly groups this body-Accepted record among superseded entries (D9). |
| [Cookie domain scope](../adr/cookie-domain-scope-by-surface.md) / [cookie docs](../docs/security/cookie-domain-scope.md) | `PreferenceCookieName`, `PreferenceIoKeys`, `PreferenceBase#preference_cookie_options`, `PreferenceCookieWriter`, `CoreCookieOptions` | Implemented role-only host-local credentials; secure contexts use __Host-, Strict, HttpOnly, Path=/ and production Partitioned. Display mirrors use domain:true/HttpOnly:false. Earlier __Secure/scoped names are compatibility reads/deletions, not current issuance. |
| [Family capability](../adr/preference-browser-transport-family-capability.md) | `PreferenceBrowserControlsRegistry`, `PreferenceBrowserApi`, concrete API controllers; `test/integration/preference_browser_api_contract_test.rb`, route/chrome tests | Implemented same-origin server-declared endpoints for twelve family/surface pairs; Palm/Edit no controls. Why: domain app is not endpoint capability, Palm controls 404'd, Core used a different path. Transport cleanup deliberately did not decide lifecycle redesign. |
| [Invalid recovery](../adr/invalid-browser-credential-recovery.md) | `PreferenceTransport`, `PreferenceRefreshTokenTransport`; `test/integration/preference_credential_recovery_matrix_test.rb` | Implemented normal-path refusal taxonomy, no GET rotation, one-minute stale-generation read behavior and system-failure propagation. Specialized browser APIs skip this path (D1–D3). Predecessor `preference-credential-entry-recovery.md` is Superseded. |
| [Theme](../adr/theme-preference-cookie-and-param-contract.md), [localization](../adr/localization-preference-flow.md) | `PreferenceIoKeys`, `PreferenceGlobal`, `PreferenceCore`, Actor overlays; context tests | Stable ct/lx/ri/tz and region bundle implemented. JS mirror reads in Theme API conflict with blanket Rails input prohibition (D2). Old Sign paths are historical Base predecessors. |
| [Whole-record recency](../adr/preference-relogin-reconciliation-record-recency.md) | `PreferenceAdoption#sync_preferences!/#reconcile_preference_key!/#reconcile_cookie_consent!`; behavior docs, sign-in/adoption tests | Drift D5: body is still Accepted whole-record recency, while current implementation uses per-key explicit metadata/child recency, with consent separately reconciled. No automatic ADR supersession is inferred. |
| [Core TanStack zero-cookie](../adr/tanstack-start-zero-cookie-ui-origin-boundary.md) | Global code holds Rails/RP boundary; Edge feature Core dispatcher strips Cookie/Set-Cookie around TanStack | Accepted current Global target; Edge converts language-cookie data into internal locale before stripping (E3). Real integration is Unverified. Core-specific scope is not a blanket public-host rule. |
| [No-store](../adr/global-and-publishing-default-no-store-policy.md), [cache reference](../docs/reference/http-cache-policy.md) | `DefaultNoStore`, Global/Publishing roots; `PreferenceBrowserApi#set_preference_browser_api_no_store!`; browser API assertions | Implemented explicit no-store on all Preference browser API responses. Core/Palm/Warp are excluded from Global default; exclude does not mean cacheable. Sign-out browser-history/cache safety is Unverified (A7). |

## Current credential and projection lifecycle

**Implemented:** `SecurityTokenLifetimes::PREFERENCE_JWT_TTL = 7.days`;
`PreferenceBase::REFRESH_TOKEN_TTL` and `SingleUseToken::PREFERENCE_REFRESH_TTL` are both 400 days.
`SecurityJwtPreferenceTokenCodec` uses the RFC 9068 profile, ES384, `at+jwt`, issuer/audience,
`sub == public_id`, `client_id`, `iat`, `nbf`, `exp`, `jti`, scope and preference_type. JWT host/audience
validation includes matching configured Base scope and the code's last-two-label registrable-domain
check. This fixed-domain code is not evidence of a general public-suffix implementation.

`PreferenceJwtConfiguration` derives audiences from Base boot hosts and exposes both private/public
key access. `PreferenceAccessTokenIssuer#preference_jwt_namespace` only specializes old sign/acme
controller namespaces; current base/auth/core/warp paths fall through to the common `preference`
issuer. Neither naming nor issuer scope currently proves Base-only signing.

`expires_at` is an alias of `discard_at` on all shared roots. Bootstrap writes a finite 400-day value;
ordinary rotation creates a replacement row with a new public_id/jti/verifier and moves children.
`SingleUseToken` locks consumption; replay retires the replayed row without revoking the successor.
DBSC binding can move to the successor. Some legacy/default records have infinite discard_at,
which current buffer-expiry helpers explicitly reject before producing a time-based cookie.

Access `exp` is computed from the codec's integer clock; cookie expiry is separately computed by
the issuer, with no cap to remaining DB lifetime. A write late in the row's life can therefore issue
a JWT that outlives the row. The normal GET loader checks DB state, while specialized/offline readers
have different semantics. This is the concrete reason TTL, row life and revocation must be designed
together; it is not evidence that 400 days is currently safe.

**Implemented sign-out:** `AuthenticationLogoutable` calls
`PreferenceSignOutRotation#rotate_preference_after_sign_out!`. If a row is loaded, one Preference DB
transaction creates a guest row, seeds only theme/language/timezone/region/currency/date/time/motion/
density/page-size, and retires the old row with used_at/discard_at. Consent/adult-gate/explicit flags
are not copied. Transport issuance occurs afterward. Retirement failure is separately logged and
auth logout continues; this is an intentional scoped exception to failure propagation. No loaded
Preference means this hook returns. Remote-device sign-out cannot enumerate every independent
anonymous Preference credential: the current comments explicitly accept this limitation and forbid
using Preference as authentication.

**Historical versus current:** July 2 “keep values/no rotation” behavior was replaced by July 21
safe-copy into a new credential. Preserving display values does not mean retaining the old row.
`test/integration/preference_logout_downgrade_test.rb` still has an obsolete header comment saying
only auth transport must clear; its display-survival assertion does not prove old credential retirement.

## Confirmed drift and audit findings

The following judgments are source-based. Potential impact is assessment, not a reproduced exploit.
Each finding has an owning path/contract and a bounded next verification condition.

### D1 — Specialized Theme/Consent access lookup omits retirement/generation checks

**Drift, source-confirmed.** Theme controllers under Base/Auth/Core/Warp skip `set_preferences_cookie`
and `set_current_actor`. `PreferenceWebThemeEndpoint#decoded_theme_preference_payload` verifies JWT
claims/type, but `find_preference_for_theme_update` uses a bare `lock.find_by(public_id:)`;
`update_preference_theme!` reissues access. Consent's `persist_cookie_consent!` also uses a bare lookup.
Neither applies `active.unconsumed`, `valid_refresh_preference?` or current-jti validation on that path.
The shared normal loader does apply active/unconsumed and jti checks.

**Assessment:** a valid, unexpired JWT naming a retired row reaches a materially different write path
from ordinary lifecycle reads. Whether the removed/moved child is recreated and which visible response
occurs must be reproduced at the public boundary. This is not declared an authentication vulnerability.
The July retirement guarantee in `docs/architecture/preference-behavior-contract.md` cannot be applied
to these bare lookups merely because it covers the normal loader.

**Evidence/history:** current `preference_web_theme_endpoint.rb`, `preference_web_cookie_endpoint.rb`,
`preference_access_token_transport.rb`, concrete `*/api/v0/preferences/*_controller.rb`; the July 21
normal-loader fix is in the timeline. `test/integration/preference_browser_api_contract_test.rb` verifies
media/input/CSRF/audience/no-store responses, but its accepted-theme test checks response plus ct cookie,
not retired-row exclusion. No retired-token browser-API reproduction was run. Recheck expired, consumed,
DELETED, mismatched-jti and current rows across all families before redesign implementation.

### D2 — Theme API trusts the JS-readable mirror as a fallback

**Drift, source-confirmed.** `PreferenceWebThemeEndpoint#current_color_theme` falls back to
`theme_from_public_cookie`, reading `cookies[ct]`, before `sy`. The Theme ADR/current cookie docs say
Rails request code must not trust JS-readable mirrors as Preference input. This affects API display
output; it is not evidence of canonical DB corruption or security authority. The broader behavior doc
permits guest-safe display cookies, so the written contracts themselves also disagree. Resolve precise
runtime versus display-only read ownership before adopting C.

### D3 — Consent buffer-only success bypasses persistent lifecycle

**Implemented exception / Drift against blanket persistence wording.** Without a decoded public_id,
`PreferenceWebCookieEndpoint#apply_cookie_consent_update!` writes only `preference_consented` and a
request-local override; the action returns 204. It neither uses refresh to restore a row nor creates a
row/JWT. Thus a browser with expired/missing access but valid refresh can take buffer-only success.
Persisted branches also differ from normal lifecycle (D1). The normal recovery ADR's “JSON/write 401”
rule does not describe the specialized API bypass, and db-write allowlist W10/docs claiming persist and
reissue are incomplete descriptions of this exception.

`test/integration/preference_browser_api_contract_test.rb` checks 204/Set-Cookie for accepted consent,
not durable persistence on every branch. `PreferenceConsentedBuffer` explicitly describes itself as
write-only for Rails. This is a UX helper, not a new consent authority. Reproduce buffer expiry, reload,
missing/invalid access and consent withdrawal before choosing a delivery contract.

### D4 — Current DB-reading GET versus stale runtime-cache/edit-entry docs

**Drift, source-confirmed.** Normal `PreferenceTransport#set_preferences_cookie` GET/HEAD calls
`load_access_token_preference_record!`, which queries the writing role for active/unconsumed row and
checks jti. If necessary it reads/verifies the existing refresh row without rotating/reissuing. This
contradicts `docs/architecture/preference.md` assertions of normal no-extra-DB/no-DB-jti reads.
The same doc still permits bootstrap/edit-entry JWT refresh on GET, says invalid runtime setup should
fail the request, and cites old allowlist categories; September recovery/allowlist and current code
removed those exceptions. Valid HTML refusal now detaches as specified by the newer recovery ADR.

**Audit uncertainty:** valid refresh-only lookup sets `@preferences` but does not build a JWT payload.
ActorSupport runtime hydration consumes only a verified payload (or display defaults + overlay), while
edit screens may read the loaded DB child. GET does not issue a replacement. Consequently recovered DB
row, runtime facade and specialized API output are not demonstrably equivalent after access expiry.
This path difference is confirmed in source; the exact visible mismatch needs a public-request test.
Do not label refresh lookup on GET as prohibited refresh consumption: it does not mint/extend a token.

### D5 — Re-login recency Accepted ADR disagrees with per-key code/docs

**Drift.** The May ADR is Accepted and explicitly disallows field-level merge until per-field metadata
exists. July implementation added explicit_fields plus child-record recency and special legacy NULL
handling; behavior docs call the whole-row strategy superseded. `PreferenceAdoption`'s top comment
still describes whole-record updated_at. Current three mirror migrations add nullable metadata without
backfilling existing rows, then set a default for new rows. July historical research initially reports
`default: [], null:false` and an all-rows-empty consequence; that report is Historical and does not
match current migration/code. No schema application/backfill state was queried in this session.

The implementation is evidence of change, not authorization to mark the Accepted ADR Superseded.
Final governance must explicitly reconcile it. The Proposed ADR only points out the conflict.

### D6 — Frontend access naming is ahead of implementation

**Drift.** September/October recovery and zero-cookie ADR prose uses auth_*/feel_*; current
`PreferenceIoKeys`, `PreferenceCookieName`, cookie docs, tests and browser transport still use
preference_*. No local feel_* constant/write was found. Historical auth-prf and scoped cookie names
must not be confused with either current names or the proposed feel rename. Renaming/legacy deletion
is Open and was not executed.

### D7 — General failure contract has specialized best-effort fallbacks

**Implemented / Drift where broadly generalized.** Normal refresh/access DB lookups propagate DB
exceptions; the recovery matrix contains a DB-failure propagation assertion. Theme update and consent
persistence log/rethrow. It is therefore inaccurate to claim all DB failures become defaults.

However `PreferenceWebCookieEndpoint#cookie_consent_state` rescues StandardError into four false
flags; `refresh_token_expires_at` rescues lookup failures into nil, and buffer-sync rescues into a skip.
The expiry helper does execute a DB query. Some codec configuration/key errors become nil for limited
exception classes. Adoption/resource restore/sign-out have separately nonfatal boundaries. These are
concrete fallback sites requiring scoped review against invalid-recovery's failure/refusal separation;
not every helper is proven reachable in every browser API action. No production outage reproduction
was performed. Verify exact call sites and endpoint outcome before assigning vulnerability severity.

### D8 — Historical tests/paths and stale GET assumptions

**Drift.** `test/integration/preference_get_edit_current_behavior_test.rb` expects a row after GET then
queries the latest row, but current transport has no bootstrap on GET. That test setup can select
fixture/preexisting state; its name does not establish fresh-visitor creation. Behavior docs correctly
state some private-method tests were removed, but several links target nonexistent
`research/implementation/2026-07-21-preference-lifecycle-hardening-implementation.md`. The actual
file is `research/2026-07-21-preference-lifecycle-hardening-implementation.md`.
These stale test comments/links are debt, not evidence of current passing regression coverage.

### D9 — ADR index overstates scoped supersession

**Drift.** The existing dirty `adr/README.md` groups cookie scope, soft bubbles and the September 26
Preference separation ADR as superseded IdP/RP-centered records. Cookie/soft-bubble bodies contain
scoped authority amendments; Preference separation is body-Accepted without a supersession notice.
The companion ADR follows the actual scoped records and flags the ambiguity. The user's existing
index was preserved; no blanket supersession was applied.

## Audit concerns without a confirmed defect

| Concern | Finding | Remaining verification |
| --- | --- | --- |
| Theme refresh rotation | Theme valid-access branch reissues without rotation; refresh-only branch loads but does not call refresh_refresh_token_lifetime. Normal transport rotates only its no-valid-access write path. This is a source-confirmed difference, not proof that every Theme PATCH must rotate. | Decide what “lifecycle unchanged” means; reproduce same-generation parallel writes, replay and failed lookup; distinguish jti rotation from refresh-row replacement. |
| DB outage/default conversion | Normal record lookups fail explicitly; helper fallbacks exist (D7). | Exercise public actions with dependency/config errors without declaring expected absence a failure. |
| Browser HTTP cache after sign-out | PreferenceBrowserApi sets no-store; Global/Publishing roots default no-store. Core/Warp have independent policies. SignOutClearSiteData emits Clear-Site-Data: "cache", "storage" on its logout completion hook; its comments describe browser fallback, not verified support or universal cache/history eviction. | Real-browser HTTP/BFCache/service-worker and parallel-response checks across every consumer; reset/sign-out must not re-display a privileged/withdrawn-consent representation. |
| Signing secret outside Base | Common key registry builds preference issuer from private/public keysets and requires active private key; multiple family mutation paths invoke the issuer. | Source establishes capability and public-only boot incompatibility for a configured issuer, not actual production secret distribution. Inventory deployment isolation without exposing secrets. |
| Stolen long-lived JWT | Current access verification is not universally DBSC-bound; DBSC protects refresh/registration paths. | Bound read disclosure, write authority, stale-consent duration, key compromise and reset consequences. No 400-day risk acceptance exists. |

## Edge reference investigation

**Read-only references:** GitHub main/index `185dd076404011ed391b2b550091be3fd7939ba0`
(2026-09-10), and remote feature `1218ddca851933ab2f9498ad9f426acc69f78d6b`
(2026-10-01). Feature was cloned into an isolated temporary reference directory outside Global,
without modifying either remote. No user local Edge worktree or deployed Worker was inspected.
Main is not interchangeable with feature; feature itself can lag the separately requested work.

- **E1 — Historical mirror dependency:** main
  [`app/apex/src/create-apex-app.ts`](https://github.com/seahal/umaxica-apps-edge/blob/185dd076404011ed391b2b550091be3fd7939ba0/app/apex/src/create-apex-app.ts)
  configures Hono languageDetector and Vary: Cookie, Accept-Language. Its Hurl/README describe sticky
  language-cookie precedence. This corroborates Global's `language` name/Hono compatibility rationale.
  Main apex theme uses a `theme` cookie, while Rails uses `ct`; these are not evidence of one coherent
  shared theme contract.
- **E2 — Partial cleanup, reads remain:** feature commit
  [`4929730cb6bb9982750fd2622f3003cb3e23425b`](https://github.com/seahal/umaxica-apps-edge/commit/4929730cb6bb9982750fd2622f3003cb3e23425b)
  (2026-09-15) adds caches:false and removes apex offline handling; it removes writes, not language
  reads. Feature commit
  [`c7f2e5ae4262245855fd0f9f27e3df966d7fc096`](https://github.com/seahal/umaxica-apps-edge/commit/c7f2e5ae4262245855fd0f9f27e3df966d7fc096)
  (2026-10-01) retires app/com/org apex source units. Surviving dev/net apex still configure the read
  detector. Deleted app apex is not evidence of Core/public-cell dependency removal.
- **E3 — Core locale conversion before stripping:** feature
  [`app/core/src/worker.ts`](https://github.com/seahal/umaxica-apps-edge/blob/1218ddca851933ab2f9498ad9f426acc69f78d6b/app/core/src/worker.ts)
  calls resolveDisplayLocale before stripping inbound Cookie, overwrites an internal
  x-edge-display-locale header with a validated value and removes outbound Set-Cookie.
  [`app/core/src/lib/display-locale.ts`](https://github.com/seahal/umaxica-apps-edge/blob/1218ddca851933ab2f9498ad9f426acc69f78d6b/app/core/src/lib/display-locale.ts)
  uses lx -> language Cookie -> default. Addition is visible in
  [`197b5e8bc4d3f0d7c5aa8d25e69ce074ca210186`](https://github.com/seahal/umaxica-apps-edge/commit/197b5e8bc4d3f0d7c5aa8d25e69ce074ca210186)
  (2026-09-15). **Assessment/contract drift:** stripping raw Cookie does not eliminate
  cookie-derived SSR personalization; reconcile with Global's October Core ADR, which expressly
  excludes reading feel_* or other credentials for UI personalization. The input here is a display
  mirror, not a JWT; exact intended exception and deployment remain Open/Unverified.
- **E4 — Public framework history matters:** main Edge ADR 015 accepts Astro while retaining TanStack
  builds; feature's
  [`ADR 015 amendment`](https://github.com/seahal/umaxica-apps-edge/blob/1218ddca851933ab2f9498ad9f426acc69f78d6b/adr/015-public-content-surfaces-astro.md)
  says the active twelve cells are TanStack again. Feature
  [`ADR 019`](https://github.com/seahal/umaxica-apps-edge/blob/1218ddca851933ab2f9498ad9f426acc69f78d6b/adr/019-edge-parallel-contract-boundaries.md)
  governs current content transport: no request Cookie/Authorization forwarded to Rails, fixed public
  reads, no public-network fallback. Public locale helpers retain language reads, but the URL/SEO
  integration is deferred. `app/docs/src/request-handler.ts` passes the bounded request to the router;
  unlike Core it does not itself strip Cookie. Its `src/lib/rails-client.ts` strips credentials on the
  upstream hop. Do not equate upstream stripping, UI cookie stripping and deferred locale use.

**Verdict:** language dependency removal is **not complete in the inspected remote feature**.
Removal of issuance and some apex units is confirmed; separate unpushed removal/deployment is
Unverified. No file was changed, and historical ADR 019 does not authorize restoring a dependency
that the designer separately requested removed. Alternative B remains a proposed boundary change,
not an existing approved Preference BFF.

## Newly stated design intent on 2026-10-11

These are **designer statements / Proposed**, not historical Git proof or final accepted design:

- Preference was derived from auth-cookie technical experiments; this origin motivates reconsidering
  the inherited lifecycle.
- Favor deleting dedicated feel_refresh/feel_dbsc, centralizing DB changes and signing/issuance on
  Base, sharing one HttpOnly JWT inside each registrable domain, and public-key-only consumers.
- Preserve Actor.preferences and use a direct shared resolver; separate frontend representations.
- Consider 400 days for access after refresh removal; do not decide it yet.
- Leave Rails BFF, TanStack-specific Preference API and noncredential display cookies A/B/C open.
- Strengthen QA for possible mixed cookie generations without representing QA as atomicity.
- Keep auth/RP/OIDC/session security out of scope, continuity unimplemented, and the separate Edge
  language removal request active. Continue review over roughly three months without auto-approval.

**Assessment:** Base-only issuance and registrable-domain sharing directly differ from current
host-local endpoint issuance and __Host- credentials. Public-key-only verification also differs from
current normal Rails DB retirement checks and global private-key validation. These are structural
changes requiring an accepted decision, not mere TTL/constants cleanup.

## Affected implementation inventory for future design — no execution plan

| Owner/boundary | Existing paths requiring assessment if the proposal is approved |
| --- | --- |
| Shared surface DB records | `app/models/{app,com,org}_preference.rb`, matching option/child/cookie/status/binding/dbsc models, `app/models/{app,com,org}_setting_record.rb`, `db/{app,com,org}_setting_structure.sql` and matching migration histories |
| Actor-local state | `app/models/{client,operator,visitor}_preference.rb`, child/option models, `app/models/concerns/preference_explicit_fields.rb`, principal-to-zenith connection boundary |
| Runtime/direct resolution | `app/models/actor.rb`, `app/models/actor/preference.rb`, `app/controllers/concerns/actor_support.rb`, `preference_{global,base,localization,class_registry}.rb` |
| Signing, TTL and claims | `preference_token.rb`, `preference_jwt_configuration.rb`, `preference_access_token_issuer.rb`, `app/values/security_jwt_preference_token_codec.rb`, `security_token_lifetimes.rb`, `lib/jit_security_jwt_{registry,keyring,key_source}.rb`, `config/initializers/jwt.rb` |
| Cookie/refresh/binding | `preference_{io_keys,cookie_name,cookie_writer,access_token_transport,refresh_token_transport,transport,dbsc_registration_endpoint,consented_buffer}.rb`, `app/models/concerns/{single_use_token,refresh_token_shared,dbsc_bindable}.rb`, DBSC services, `app/values/core_cookie_{options,domain}.rb`, `lib/jit_session_cookie_config.rb` |
| Mutation/adoption/reset/sign-out | `preference_{core,resource_sync,adoption,sign_out_rotation,web_theme_endpoint,web_cookie_endpoint,web_theme_actions,web_cookie_actions}.rb`, `authentication_{base,logoutable}.rb` Preference integration only; preserve auth owner contracts |
| HTTP capability/transport | `PreferenceBrowserApi`, `app/values/preference_browser_controls_registry.rb`, `app/controllers/{base,auth,core,warp}/{app,com,org}/api/v0/preferences/*`, Base `/preference/*`, `config/routes/{base,auth,core,warp}.rb`, DBSC registration controllers/routes |
| Frontend display | `src/lib/{request,theme}.ts`, theme/browser cookie scripts, theme/consent React/Stimulus controls, server chrome props and layouts; current cookie reads and endpoint results need consistent generation rules |
| Public content and cache | `app/controllers/{info,docs,news,help}/{app,com,org}/bare_controller.rb`, Publishing rendering, DefaultNoStore, family cache/sign-out history boundaries; public roots intentionally lack Preference lifecycle |
| Existing verification | Preference browser API/route/chrome, recovery matrix, refresh replay, sign-in/adoption/dual-write/read-symmetry, GET-edit, consent and sign-out integration/model tests; do not revive private-method tests |
| Edge reference only | Core worker/display-locale, public cell request handlers/content clients, surviving dev/net apex detectors, ADR 019 and retired apex ADR 024. User local Edge source/deployment must be rechecked later. |

## Conditions to settle and verify before implementation

The companion ADR's lifecycle table owns design questions; this list records gaps actually identified
by investigation, not planned work already performed.

1. Resolve governance for per-key merge, current normal DB reads, mirror input and all GET exceptions.
   Define which existing scoped ADRs will be superseded, rather than treating the index as approval.
2. Prove one expiry instant across JWT/cookie, finite DB expiry and exact boundaries (below/at/above),
   infinity handling, clock skew and old-key lifetime from final issuance. Confirm actual browser
   retention and anonymous expired-cookie outcome. No hidden recovery mechanism is approved.
3. Exercise current/retired/consumed/DELETED/mismatched-jti JWTs through all API mutations and reads;
   expired access plus valid refresh must have an explicit non-issuing GET and write contract.
4. Define Base-only write/issuance capability and public-key-only boot; inventory actual recipient
   hosts and key/secret provisioning. Verify family/domain issuer, audience, typ, scope and key-revoke
   rejection without disclosure or widening auth trust.
5. Define stale projection acceptance after mutation/reset/sign-out, including offline Edge, stolen
   copies, key compromise and remote devices. The DB source of truth and signature verification are different claims.
6. Decide A/B/C with the real Edge branch and unpushed removal work; any Preference BFF needs an
   explicit API-route/credential boundary. Public content upstream credential stripping stays intact.
7. For independent display cookies, specify bounded impact, detectable and undetectable skew,
   recovery source/action and safe failure; then verify partial updates, concurrent tabs, response
   inversion, tampering, eviction and stale caches. QA alone supplies no atomicity.
8. Preserve sign-out guest-safe copying without consent/age/security authority; verify DB errors
   distinguish missing credentials from dependency failure and auth logout remains independent.

## Checks completed in this session

- Read root AGENTS, model calibration, repository-language/knowledge/notes/source rules and relevant
  surface/browser/authentication/failure/Concern boundary material; inspected README topology.
- Inspected all fourteen prioritized ADR/docs references, adjacent authority/cache/DB-write documents,
  related archive/backlog, current research and evidence. `plans/active`, `plans/analysis` and `memos`
  are absent now; October 9 knowledge consolidation explains moved material. Historical old paths
  were consulted with Git rather than recreated. Closed/rejected material was not executed.
- Used `git log --follow` on Preference base, Actor value, cookie names, transport and owning docs/ADRs;
  inspected diffs for each listed chronological milestone, including generic checkpoint commits.
- Queried Edge GitHub read-only, pinned main/feature revisions, inspected full files and cloned the
  feature into a temporary directory for source searches/history. Initial expected app apex paths
  returned 404 on feature; the retirement diff explains that absence. Guessed ADR paths returning
  404 were replaced by the actual ADR 019 path from the reference checkout.
- Inspected existing tests for claimed contract coverage without running them. No new tests added.
- Final checks on the two new documents found no missing local Markdown targets or accidental
  trailing whitespace (intentional Markdown hard breaks were initially exempted). The subsequent
  `git diff --no-index --check /dev/null <file>` flagged those hard-break spaces; they were replaced
  with blank lines and both checks then passed. `git cat-file -e <sha>^{commit}` validated all 24 unique Global commit links.
  A first check invocation failed because `python` was unavailable; rerunning with `python3`
  completed the document/reference checks.
- Compared SHA-256 values against the start-of-task snapshot of 43 existing dirty/untracked files:
  41 matched; `test/operations/avatar_ownership_transfers_concurrency_test.rb` and
  `test/support/parallel_test_database_cloner.rb` changed during the session. This task did not
  write either file. The preservation assertion therefore failed for the whole snapshot; those
  concurrent changes were retained, not reverted. Additional unrelated work appeared in final
  git status (including `docs/operations/db-workflow.md`, an integrated-stack acceptance file and
  an Avatar evidence record); it is not task-authored. The snapshot did not hash the preexisting
  `.claude/` directory or clean tracked files, so it is not a whole-tree identity proof.
- Task write operations targeted only the two requested Markdown artifacts. No implementation,
  tests, configuration, schema or existing Accepted ADR was edited by this investigation.
  No application tests were run; runtime reproduction and deployment checks remain Unverified.

## External protocol references checked

[MDN Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie)
was read for host/domain scope, public suffix exclusion, __Host-/__Secure-, HttpOnly and independent
cookie updates; [RFC 7519 expiration](https://www.rfc-editor.org/rfc/rfc7519.html#section-4.1.4)
was read for signed-token absolute validity. These protocol constraints inform the Proposed questions,
not a decision to use 400 days. No forbidden third-party article sources were used.
