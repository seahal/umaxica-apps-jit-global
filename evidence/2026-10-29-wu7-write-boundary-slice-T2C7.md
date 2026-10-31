# WU-7 slice 1: PreferenceWriteBoundary (closed operation contract) on the com surface

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; worktree carries WU-3..WU-5 plus this slice;
  nothing committed.
- Scope: the D-54/AC-24 write entry itself (two.md section 4.4). The concern is a *first slice*: it
  owns the closed operation enumeration and the static surface/realm/operation contract; the com
  controller delegates its pre-write authorization to it. JWT claims reshaping (section 4.2) and the
  section-4.3 column migration are later slices in the same loop and remain gated (see "Not in
  this slice").

## What was written

- `app/controllers/concerns/preference_write_boundary.rb` — new concern:
  - `OPERATIONS = %i(save sign_in sign_out reset).freeze` (the closed set).
  - `SURFACE_REALMS` — static surface-to-realm map with per-surface operation subsets: Base surface
    keys may use `save`/`reset`, Visa keys `sign_in`/`sign_out`; unlisted surfaces are refused.
  - `PreferenceWriteBoundary.authorize!(surface_key:, operation:, realm_model:)` — validates the
    operation against the closed set, the surface against the map, the surface against the realm of
   the model class it claims to write, and the operation against the surface's own subset. Raises
   `PreferenceWriteBoundary::UnsupportedOperationError` / `UnsupportedSurfaceError` and fails closed.
- `app/controllers/base/com/preferences_base_controller.rb` — `authorize_preference_write!` now
 delegates to the boundary first (`surface_key: "base/com"`, `operation: :save`) before the existing
 `realm_model == ComPreference` check, so every com write admission flows through the one entrance.
- `test/controllers/concerns/preference_write_boundary_test.rb` — new coverage: closed-operation
 acceptance on owning surfaces, Visa sign_in/sign_out on their realms, refusal of an operation
 outside the set, refusal of sign_in at Base (Visa-only operation), refusal of an unlisted surface,
 and refusal of a surface naming another realm's model. 6 runs / 19 assertions / 0 failures.

## Verification

- `PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/preference_write_boundary_test.rb`:
  6 runs, 19 assertions, 0 failures, 0 errors, 0 skips.
- Full-file syntax: `ruby -c` passes on both new/edited app files.
- Regression guard: `bin/rails test test/controllers/base/com test/integration/preference_web_csrf_test.rb`
  → 21 runs, 73 assertions, 0 failures, 0 errors, 0 skips; the pre-write slice
  `bin/rails test test/controllers/base/preference_authority_slice_1f_test.rb` stayed 17 runs green.
- Rubocop: clean on the three touched files (`-A` applied; borderline ASCII/comment and
  visibility findings resolved manually per Umaxica rules).

## Not in this slice (next steps in WU-7, owner-visible)

- JWT claims shape per section 4.2 (`preferences` closed-key object, no `client_id`/`host`/
  `preference_type`/`prepend claims`) — touches `SecurityJwtPreferenceTokenCodec` and every reader.
- Section 4.3 column migration for `com_preferences` (dropping `token_digest`/`dbsc_*`/
  `binding_method_id`/`replaced_by_id`/`used_at`, adding `last_issued_at`/`last_issued_expires_at`,
  `jti UNIQUE NOT NULL`) is a destructive schema change under two.md section 3.0's "shape review
  before implementation" gate — the review is the pending owner decision before further surgery, and
  the *shape* gates are separate from this code slice.
- Visa surface wiring (`sign_in`/`sign_out` paths) opens in WU-9 per the plan, not in WU-7.
