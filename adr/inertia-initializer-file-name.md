# Inertia Rails Initializer File Name

Accepted: 2026-10-14

## Context

The Inertia Rails documentation shows its configuration in `config/initializers/inertia.rb`. This
repository keeps it in `config/initializers/inertia_rails.rb`. Rails loads every `.rb` file under
`config/initializers/` in alphabetical order regardless of its name, so the name has no runtime
effect here: no Inertia setting depends on load order relative to another initializer.

## Decision

The Inertia Rails configuration lives in `config/initializers/inertia_rails.rb`, and the file name
is not renamed to match the documentation.

- The name follows the gem name (`inertia_rails`), the same convention other gem initializers use,
  so a search for the gem finds its configuration.
- `inertia.rb` is not used, to leave that name free for any future non-gem Inertia concern and to
  avoid a second initializer holding part of the configuration.
- When upstream documentation shows `config/initializers/inertia.rb`, its `InertiaRails.configure`
  content is merged into the existing file; it is never added as a second file.

## Consequences

- No behavior change and no migration.
- The file stays the only place that calls `InertiaRails.configure`; its contents remain governed by
  `adr/inertia-rails-thin-adapter.md`.
