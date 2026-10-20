# rails-erd scoped connection fix: reproduction and verification

- Application commit: `2b23e9d20c61c695a5eb2353cbca70f9d900d3f4` (clean worktree). The Gemfile was
  pointed at `vendor/fork/rails-erd` only for the runs below and restored afterwards.
- rails-erd: fork `seahal/rails-erd`, branch `fix/scoped-connections`, commit
  `43dcb3423753be9df3a93b2db6be494b8a450b6a` on top of upstream `8ce4dd1` (v2.2.0). Not pushed.
- Ruby 4.0.7. Application settings: `permanent_connection_checkout = :deprecated`, deprecations
  `:raise`.

## Cause

`Attribute#native_type` and `Diagram::Tbls#indexes_payload` call `Model.connection`. While the
thread holds no leased connection, ActiveRecord 7.2+ warns (`:deprecated`) or raises
(`:disallowed`). The tbls path rescues `StandardError` and silently emits no indexes.

## Fix

Both call sites use `Model.connection_pool.with_connection`. No dependency or version branching.

## Gem tests (`bundle exec rake test`, SQLite)

| Gemfile             | ActiveRecord | before fix (new tests) | after fix       |
| ------------------- | ------------ | ---------------------- | --------------- |
| root Gemfile        | 7.2.4        | 1 failure, 2 errors    | 410 runs, 0 F/E |
| Gemfile-rails.7.0.x | 7.0.10       | not run                | 410 runs, 0 F/E |
| Gemfile-rails.7.1.x | 7.1.6        | not run                | 410 runs, 0 F/E |
| Gemfile-rails.7.2.x | 7.2.4        | not run                | 410 runs, 0 F/E |
| Gemfile-rails.8.0.x | 8.0.5.1      | 1 failure, 2 errors    | 410 runs, 0 F/E |
| Gemfile-rails.edge  | 8.2.0.alpha  | 1 failure, 2 errors    | 410 runs, 0 F/E |

All runs: 2 pre-existing skips. Only Ruby 4.0.7 was available; other Ruby versions of the upstream
CI matrix were not run. On 7.0/7.1 the new tests run without the setting, which does not exist
there.

## Application

- `bundle exec erd --generator=graphviz --filetype=pdf`, unmodified gem:
  `Failed: ActiveSupport::DeprecationException` from `attribute.rb:166`, no PDF, exit status 0.
- Same command, fixed gem: exit 0, no deprecation, 369,852-byte file starting `%PDF-1.7` and ending
  `%%EOF`, about 8 s. The dot output of the same domain has 893 entity nodes and 1,100 edges. Page
  rendering was not inspected (no PDF tool installed).
- Mermaid output (`--generator=mermaid`) is byte-identical between unmodified and fixed gem.
- `bin/rails runner` matrix over checkout `true`/`:deprecated`/`:disallowed` × deprecation
  `:raise`/`:log`: the fixed gem produced a PDF in all six. The unmodified gem failed only under
  `:disallowed`; under `:deprecated` it did not reproduce the CLI failure. The cause of that runner
  difference was not determined.

## Standalone A/B reproduction

A script outside the application (SQLite, one `widgets` table with a unique index, schema created
inside `with_connection` so no connection is leased) ran upstream `8ce4dd1` (A) and `43dcb34` (B),
one process per target, under ActiveRecord 7.2.4:

| checkout      | deprecation | A: Graphviz PDF                         | A: tbls indexes   | B: PDF       | B: indexes |
| ------------- | ----------- | --------------------------------------- | ----------------- | ------------ | ---------- |
| `true`        | raise / log | ok                                      | 1 index           | ok           | 1 index    |
| `:deprecated` | raise       | `DeprecationException` at `native_type` | `[]` (swallowed)  | ok           | 1 index    |
| `:deprecated` | log         | ok, 1 deprecation logged                | 1 index, 1 logged | ok, 0 logged | 1 index    |
| `:disallowed` | raise / log | `ActiveRecordError` at `native_type`    | `[]` (swallowed)  | ok           | 1 index    |

- ActiveRecord 8.2.0.alpha (edge), `:raise` only: same A failures and B successes.
- With `ActiveRecord::Base.lease_connection` called before the run, A succeeded under `:deprecated`
  and `:disallowed`: the check applies only while the thread holds no leased connection. This is a
  likely, unconfirmed explanation of the earlier `bin/rails runner` difference.
