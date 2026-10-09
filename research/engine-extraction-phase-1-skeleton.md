# Engine Extraction Phase 1 Skeleton Note

This note records completion of the engine skeleton and deployment gate work for issue `#553`.

## Status

Completed on 2026-04-07.

## Context

Phase 1 was the minimal engine bootstrap:

- add `Jit::Deployment`
- register the local engine gem
- keep the engine loadable without moving controllers or models
- gate route loading by deployment mode

## Evidence

- `lib/jit/deployment.rb` provides the deployment gate.
- `engines/local/lib/jit/local.rb` and `engines/local/lib/jit/local/engine.rb` define the local
  engine.
- `engines/local/jit-local.gemspec`, `engines/local/Rakefile`, and `engines/local/config/routes.rb`
  exist.
- `Gemfile` includes `gem "jit-local", path: "engines/local"`.
- `config/routes.rb` loads global and local routes based on `Jit::Deployment`.
- `test/unit/jit/deployment_test.rb` covers the deployment helper.
- `test/integration/jit/deployment_routes_test.rb` covers route gating in `global`, `local`, and
  `development` modes.

## Validation

- `bundle exec ruby -e "require_relative 'lib/jit/deployment'; ..."` now returns `development`,
  `true`, `true`.
- `bundle exec rails runner "puts Jit::Local::Engine.engine_name"` returns `jit_local`.
- `bundle exec rails test test/unit/jit/deployment_test.rb test/integration/jit/deployment_routes_test.rb`
  passes.
- `bundle exec rubocop lib/jit/deployment.rb config/routes.rb test/unit/jit/deployment_test.rb test/integration/jit/deployment_routes_test.rb`
  passes.

## Consequences

- Phase 1 can leave `plans/active/`.
- The parent issue `#553` stays open because later engine-extraction phases remain.
