# Test parallel reader/writer DB split

Rails process-parallel tests now run from the standard `parallelize(workers: :number_of_processors)`
configuration in `test/test_helper.rb`.

The test `*_replica` connections intentionally use separate physical database names from their
writer counterparts. In the test section of `config/database.yml`, replica configs are not marked
with `replica: true` so Rails database tasks and parallel worker schema reconstruction include those
reader databases. They use the same migration path and schema dump as the writer so
`bin/rails db:migrate:reset` can rebuild both sides. The application still routes reads through the
existing `connects_to` `reading:` role names.
