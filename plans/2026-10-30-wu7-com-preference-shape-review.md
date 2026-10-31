# WU-7 — Com preference schema shape review (owner-gated)

**Status:** Historical shape proposal for the owner review required by `two.md` section 3.4 and
the `WU-P0` / §12.8 gates. The owner subsequently authorized destructive local schema work.
The local test schema now implements the com lifecycle, receipt, browser binding and Web Push
representation; see `evidence/2026-10-31-wu7-schema-review-K2M8.md` and the referenced migration
evidence. The Before observations below describe the original proposal, not the current schema.
This document does not establish production application or WU-7 closure.

**Owner disposition (2026-10-31):** WU-7 is provisionally accepted so subsequent work units may
proceed. The owner deferred deciding the outstanding failures until acceptance testing. This is
not formal closure or a change to the recorded test results. Retain the 22 baseline-external
candidate failures in `evidence/2026-10-31-wu7-full-suite-completed-N7P5.md` for that review.
The separate purge execution ticket remains unapproved; provisional acceptance does not execute
or schedule data collection or authorize a production/Neon operation.

**Inputs:** `two.md` (commit-recorded input) sections 4.1-4.3, 4.9, 12.7, 12.8; `two.md`
appendix S.1/S.2/S.3 as the DDL baseline; the *current* worktree `db/com_setting_structure.sql`
(additive deltas below where earlier WU-7 slices changed it: the browser-binding digest column
and its unique index arrived additively in `db/com_settings_migrate/20261029213000_add_preferences_browser_binding_digests.rb`).

## Scope of this review request

`com_setting` only (WU-7). The `app_setting` / `org_setting` / zenith halves of appendix S are
WU-9 aspects of the same review; they are listed at the end so the owner can approve the family
in one pass or separately.

## Current com state (measured worktree + dev database, not a promise about production)

- `com_preferences`: `public_id` (21 chars, immutable), `jti` nullable, `status_id` →
  `com_preference_statuses` (`NOTHING = 2`, `DELETED = 1`), `explicit_fields` NOT NULL,
  `discard_at` / `purge_eligible_at` with `'infinity'` defaults and NOT NULL constraints, legacy
  transport columns `binding_method_id`, `dbsc_status_id`, `dbsc_challenge`,
  `dbsc_challenge_issued_at`, `dbsc_public_key`, `dbsc_session_id`, `token_digest`, `used_at`,
  `replaced_by_id`.
- `com_preference_cookies`: four NOT NULL booleans, nullable `consent_version` +
  `consented_at`, unique `preference_id`, and the additive `browser_binding_digest`
  (`varchar(64)`, nullable) with a **unique** index
  `idx_com_pref_cookies_on_binding_digest`.
- Dev database (`development_com_setting_db`) observed this session: 0 `com_preferences` rows,
  0 `com_preference_cookies` rows. Test database: 2 rows, both `status_id = 2`. Row counts are
  path-dependent and **must be re-measured per environment on the approval ticket**; they are
  recorded here only as the observation that the dev/test stores are effectively empty of
  binding digests, which makes the com column moves trivial in these environments and says
  nothing about production.

## Before / After (com realm, from S.1 rows 1-2 and section 4.3)

| Table | Before (current worktree) | After (adopted design) | Migration shape |
| --- | --- | --- | --- |
| `com_preferences` | legacy transport columns above; nullable `jti`; `status_id` with NOTHING/DELETED; `explicit_fields` NOT NULL; `discard_at`, `purge_eligible_at` infinity columns; no issuance snapshot | remove all legacy transport columns, `discard_at`, `purge_eligible_at`, `explicit_fields`; `jti` NOT NULL UNIQUE; `status_id` reference re-labelled `active` / `retired`; add `last_issued_at`, `last_issued_expires_at` NOT NULL | one DDL migration per concern group, plus the code-side rename of `ComPreferenceStatus::NOTHING`/`DELETED` call sites in the same change (no alias methods); purge eligibility derived as `last_issued_expires_at + 30 days` at purge time, not stored a second time |
| `com_preference_cookies` | booleans + nullable `consent_version`, `consented_at`; `browser_binding_digest` column + unique index | keep the four booleans NOT NULL; move `consent_version`/`consented_at` to a receipt child; remove the digest column and the unique index (the digest is per binding row, and the copy pair during sign-out share one digest by design) | column-drop migration with the receipt table created and populated in the same change |
| `com_preference_consent_receipts` | does not exist | `preference_id` FK UNIQUE NOT NULL, `version` uuid NOT NULL, `recorded_at` NOT NULL, chosen decision booleans stay on the cookie row | new table; a positive save writes the receipt in the same setting transaction; denials record a receipt without flipping the stored decision |
| `com_preference_browser_bindings` | digest rides the cookie row | `preference_id` FK UNIQUE NOT NULL, `digest` NOT NULL (digest itself deliberately **not** unique: the sign-out copy pair share one value temporarily) | new table; existing com digest values (0 in dev/test) would seed the table before the column drop |
| `com_preference_web_push_options`, `com_preference_web_pushes` | do not exist | option reference table plus child (`preference_id` FK UNIQUE, `option_id` FK NOT NULL), initial state disabled; delivery/subscription stays out of WU-7 | additive only |
| `com_preference_binding_methods`, `com_preference_dbsc_statuses` | reference tables for the legacy transport | removed together with the columns that point at them | drop after no writer reads them |
| display/option child tables (theme, language, region, currency, date/time format, motion, density, page size, adult_content_gate) | unchanged this cycle | unchanged; per-option FK/UNIQUE/NOT NULL guarantees asserted in the value tests; `adult_content_gate` stays dormant in the model layer per the accepted age-gate ADR | none |

Cookies and JWTs continue to carry the display projection; removing the anonymous
`explicit_fields` column is only correct together with the §4.5 rule that every display save
writes exactly the named child records (which the WU-7 write boundary already does).

## Ordering and recovery (per §12.8)

1. Measure per environment: `com_preferences` and `com_preference_cookies` row counts, per
   `status_id`, digest-bearing rows and receipt-bearing rows; snapshot `com_setting` before any
   DDL (snapshot id, restore command and restore time recorded on the approval ticket).
2. Additive migration first: statuses re-labelling handled as the last step of the same
   migration that adds `last_issued_at` / `last_issued_expires_at` and the three new tables, so
   pre-migration code never sees a half state; backfill `last_issued_*` from the JWT expiry the
   writer knows (`discard_at` alias) for existing rows.
3. Caller migration (code only, no DDL): move every com reader/writer off the removed columns
   and onto the receipt/binding/push tables; the legacy representations stay readable until this
   step closes.
4. Destructive migration last: drop columns/tables, unique-index rebuild, then
   `bin/rails db:verify_no_schema_drift`. Restoration path is the pre-migration snapshot plus the
   pre-migration checkout; a `down` path must not be claimed to restore dropped values.

## Owner decisions needed before implementation

1. Status reference: re-label row 2 as `active` and row 1 as `retired` (wire values renamed,
   IDs stable), or add two new rows and retire the old pair. Adopted design in S.1 says
   "existing reference re-labelled", so the proposal keeps IDs 1/2 stable.
2. Confirm the binding target shape (dedicated `com_preference_browser_bindings` row with a
   re-movable digest) versus the interim cookie-column implementation the WU-7 slices shipped.
   The design of §4.3 requires the table; the interim is recorded as transitional.
3. Web Push option naming: the closed option list (`enabled` / `disabled`) with `disabled` as
   the initial default.
4. The destructive migration approval, including a measured production row count and the
   backup/restore ticket; the empty dev/test counts above do not satisfy that requirement.

## Non-goals

No app/org migration in this request (WU-9), no key-rotation execution, no purge run (the purge
job remains the §4.9 periodic design gated on the same approval), no change to the 400-day read
contract or the `retired`-never-returns-to-`active` rule.
