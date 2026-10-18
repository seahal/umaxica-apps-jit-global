# Model class body reorder for Layout/ClassStructure

- Commit: `4db9b93c3842dd37f8dd3a58f39bd46f83318d36`, with the reorder uncommitted in the worktree
  when the checks ran.
- Date: 2026-10-09. Run inside `global-devcontainer-core`.

## What was done

With `app/models/**/*.rb` temporarily added to the `Layout/ClassStructure` `Include`, RuboCop
reported 356 offenses in 180 model files. 176 files were reordered. RuboCop's own autocorrection was
not used: declarations were moved with a throwaway script that keeps the relative order inside each
category and leaves statements outside every category in place, and `app/models/actor.rb` was edited
by hand. Every changed file has the same set of non-blank lines as before.

Twelve pre-existing `Layout/EmptyLinesAroundMethodBody` and `Layout/EmptyLinesAroundAccessModifier`
offenses under `app/models` were fixed with `rubocop -a --only`.

## Equivalence check

A runner script dumped, for all 802 `ActiveRecord::Base` descendants under `RAILS_ENV=test`, every
callback chain in order (including validators with their attributes and options), ancestors,
reflections with options, table name, primary key, attribute types, encrypted attributes, enums,
attribute aliases, and method and constant names. The dump was taken before and after the reorder.

- No callback chain other than `validate` changed in any class.
- The `validate` chain changed order, with the same members, in 12 classes: `Client`, `Operator`,
  `Visitor`, `ClientEmail`, `VisitorEmail`, `ClientTelephone`, `VisitorTelephone`,
  `ClientSignUpFlow`, `VisitorSignUpFlow`, `TelephoneOccurrence`, `MemberStatus`,
  `VisitorSecretCredentialKind`. Associations now precede validations, so the validators an
  association adds run before or after the class's own. The custom validators inside the moved spans
  (`effective_binding_has_digest`, `legacy_state_matches_status`, `step_matches_status`,
  `completed_status_has_completed_at`, `validate_body_format_unless_hmac`) do not read `errors`. The
  observable difference is the order of error messages when several validations fail together.
- The encrypted-attribute set of `Client`, `Operator` and `Visitor` lists the same members in a
  different order.

## Not moved

`app/models/actor/authentication.rb`, `configuration.rb`, `preference.rb` and `selected_context.rb`
keep 6 offenses. Each defines `NULL = new.freeze` (or `new(null: true)`), which must be evaluated
after `initialize` and, in `authentication.rb`, after a private method that `initialize` calls.
Because of these, `Include` in `.rubocop.yml` still names controllers only.

## Commands and results

| Command                                              | Result                          |
| ---------------------------------------------------- | ------------------------------- |
| `bin/rails runner 'Rails.application.eager_load!'`   | loaded without error            |
| `bin/rails test test/models`                         | 3703 runs, 0 failures, 0 errors |
| `bin/rails test`                                     | 14906 runs, 1 failure, 1 error  |
| `bundle exec rubocop` (committed configuration)      | 5304 files, no offenses         |
| `bundle exec rubocop` with models added to `Include` | only the 6 offenses above       |

The full-suite failure and error are `PrimaryDatabaseOwnershipTest` (expects `test_primary_db_N`,
got `test_publishing_db_N`) and `RecoverySecretParallelGetTest` (`visitor_device_session is nil`),
the same two recorded in `2026-10-10-rubocop-strict-configuration-H4KT.md`.
