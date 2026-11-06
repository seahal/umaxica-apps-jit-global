# WU-A3 local Admission Binding foreign-key normalization

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this record was added, the worktree had
  372 unstaged tracked paths and 83 untracked paths, with no staged changes. Existing work was
  preserved; no commit was created.
- The first attempted normalization was rejected by Strong Migrations because it dropped a validated
  foreign key before adding its replacement. The transaction rolled back; read-only checks confirmed
  the original constraints remained. A later migration load detected class-name collisions with
  existing 20261101031900 validation migrations before applying anything. The migrations were split
  into add-not-valid, validate, then remove-legacy steps and given unique class/file names.
- Applied migrations `20261101073137`–`20261101073139` to local development/test `op_base_app`, and
  `20261101073142`–`20261101073144` to local development/test `op_base_org`. Development's prior
  generated FK names (`fk_rails_906f9bfe56` and `fk_rails_a420b497ee`) were removed only after the
  explicit named constraints were validated. Test already had the named constraints; no duplicate
  was added or removed there.
- Before and after counts were unchanged: development App/Org bindings 0/0; test App 40 (status IDs
  10:13, 20:7, 30:17, 40:3), test Org 0. All four local databases now report the expected named
  `status_id` FK, `ON DELETE RESTRICT`, and `validated=true`; all four migration-status checks
  report no pending migrations.
- Ruby syntax and targeted RuboCop passed for all six new migrations. `git diff --check` passed. The
  existing OP Base structure dump files were byte-identical to their pre-migration snapshots (App
  SHA-256 `2c5b78f1f534edcaf47931357c22eeb8e8164ba731b4cf9bab4ac0da13b8c9be`; Org SHA-256
  `257b75971a13620fb9f4ce6780e6c040d15ef863539d0b6de5af7a38eacac73f`). No Minitest was run for this
  database-environment operation.
- After migration, the focused WU-A3 public-flow command for the AC-53 race, admission boundary, and
  App/Org sign-in/sign-up controllers completed with 80 runs, 1,289 assertions, 0 failures, 0
  errors, and 0 skips. Test output included existing NanoID frozen-string warnings.
- Only local development/test databases were accessed. Production and Neon were not accessed. This
  closes only the binding-FK name discrepancy; WU-A3 acceptance, other schema-drift discrepancies,
  and the full `two.md` work remain open.
