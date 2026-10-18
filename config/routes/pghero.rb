# typed: false
# frozen_string_literal: true

# PgHero owns the PostgreSQL monitoring dashboard (PgHero::Engine), on its own dedicated host.
# Public canonical host: pghero.umaxica.dev. Development host: pghero.core.dev.localhost.
constraints host: [ENV["PUBLIC_PGHERO_URL"], ENV["PRIVATE_PGHERO_URL"],
                   "pghero.core.dev.localhost",].compact do
  # `pghero` is a `group :development` gem (Gemfile); it is not in the test group's load path,
  # so the engine constant does not exist while running the test suite.
  if defined?(PgHero::Engine)
    # HTTP Basic Auth is applied as engine middleware in config/initializers/pghero.rb, not by
    # wrapping the engine in a Rack app here: a wrapped engine is no longer recognised as a Rails
    # app by `mount`, which then hands it a mount-relative PATH_INFO its own route set never
    # matches, so every request 404s past the engine. Mount it directly and keep the credential
    # check inside its own stack.
    mount PgHero::Engine => "/", :as => :pghero
  end
end
