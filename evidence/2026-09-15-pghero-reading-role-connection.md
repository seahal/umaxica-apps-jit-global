# PgHero ActiveRecord::ConnectionNotDefined on the mounted engine

## Symptom

`GET|POST /<database>/...` on the PgHero host (e.g. `/primary/enable_query_stats`) returned 500 with
`ActiveRecord::ConnectionNotDefined (No database connection defined for PgHero::Connection::DatabaseNNNNN.)`.

## Cause

PgHero 4.0.1 `PgHero::Database#build_connection_model` creates one anonymous `PgHero::Connection`
subclass per database and calls `establish_connection`, registering a pool for the **writing role
only**. `config/initializers/multi_db.rb` enables `ActiveRecord::Middleware::DatabaseSelector`, which
wraps requests in `connected_to(role: :reading)`; the PgHero model has no reading pool there.
Identical to the Flipper case documented in `config/initializers/flipper.rb`.

Outside a request (`bin/rails runner`) the same model connects fine, which is why the failure only
appears over HTTP.

## Fix

`config/initializers/pghero.rb` now declares both roles for every PgHero database model
(`connects_to(database: { writing: spec, reading: spec })`, models marked abstract as `connects_to`
requires).

## Verification (2026-09-15, development)

In-process `Rack::Test` against `Rails.application`, host `pghero.core.dev.localhost`, HTTP Basic
credentials from `.env`:

- before fix: `GET /primary` 500 (first request 200, subsequent 500), `POST /primary/enable_query_stats` 500
- after fix: `GET /primary` 200 twice, `POST /primary/enable_query_stats` 302, `GET /app_zenith` 200
- `bundle exec rubocop config/initializers/pghero.rb` - no offenses

Not run: the full Minitest suite (pghero is a `group :development` gem and is not loaded in test).
