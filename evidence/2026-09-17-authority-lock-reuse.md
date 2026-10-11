# Authority lock reuse verification

- Date: 2026-09-17 UTC
- Branch: `feature`
- Starting HEAD: `a94eaccab` (`Make authority transactions surface explicit`)
- Working tree: pre-existing README modification, `misc.md`/`refactor.md` deletions, and the
  unrelated browser-block notification files were preserved; this slice added only the three lock
  model changes and their test.

## Finding

`ClientAuthorityLock`, `VisitorAuthorityLock`, and `OperatorAuthorityLock` used `create_or_find_by!`
with a principal key plus a newly generated `created_at` and `updated_at`, and also declared a Ruby
uniqueness validation on that principal key. Active Record re-queries with all supplied attributes
after a unique-constraint failure, while a uniqueness validation can raise before the database
unique violation is reached. A second acquisition therefore could fail both because its timestamps
were different and because the validation intercepted the retry. The installed Rails relation
implementation at
`vendor/bundle/ruby/4.0.0/bundler/gems/rails-9fcdedd8e9d5/activerecord/lib/active_record/relation.rb:274-308`
confirms this behavior.

## Change

Each lock acquisition now supplies only the unique principal foreign key to `create_or_find_by!`,
then obtains the row with `lock.find_by!`. The Ruby uniqueness validations were removed; the
surface-local unique indexes remain the final constraint. The six authority creators run inside
their surface canonical writer transaction and lock the concrete principal row before rechecking
active eligibility. No route or authorization source was enabled.

## Verification

- `ruby -c` passed for all three lock models and `test/models/authority_lock_test.rb`.
- `bundle exec rubocop --format simple app/models/client_authority_lock.rb app/models/visitor_authority_lock.rb app/models/operator_authority_lock.rb test/models/authority_lock_test.rb`
  passed with no offenses.
- `git diff --check` passed.
- The new `test/models/authority_lock_test.rb` attempts two acquisitions for each surface and
  asserts one reused row. The Rails test command could not reach the assertions because the isolated
  PostgreSQL service at `127.0.0.1:5432` was unavailable (`PG::ConnectionBad`). No development,
  staging, or production database was used.

## Remaining verification

An isolated PostgreSQL run is still required for the repeated-acquisition assertion and for the
independent-connection concurrency test. The implementation is not reported as runtime-proven until
that check passes.
