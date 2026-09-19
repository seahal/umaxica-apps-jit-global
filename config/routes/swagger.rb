# typed: false
# frozen_string_literal: true

# Swagger owns the rendered view of the bundled OpenAPI descriptions, on its own dedicated host.
# Public canonical host: swagger.umaxica.dev. Development host: swagger.core.dev.localhost.
constraints host: [ENV["PUBLIC_SWAGGER_URL"], ENV["PRIVATE_SWAGGER_URL"],
                   "swagger.core.dev.localhost",].compact do
  # `rswag-ui` and `rswag-api` are `group :development` gems (Gemfile); they are not in the test
  # group's load path, so the engine constants do not exist while running the test suite.
  if defined?(Rswag::Ui::Engine)
    # Order matters, and the two mounts must not share a path.
    #
    # Rswag::Ui::Middleware is a Rack::Static built with `urls: ['']`, meaning it considers every
    # path under its mount point a candidate to serve out of the vendored swagger-ui-dist
    # directory. Mounted at "/", it would answer before the document endpoint ever ran. Declaring
    # the document mount first, on its own prefix, keeps each one addressable.
    #
    # Both engines carry HTTP Basic Auth in their own middleware stacks
    # (config/initializers/rswag_api.rb, config/initializers/rswag_ui.rb), for the same reason
    # PgHero and Blazer do: neither subclasses anything of this application, so
    # enforce_access_policy! and surface isolation never run for them. The document mount is
    # guarded separately from the UI mount on purpose -- the descriptions enumerate every internal
    # endpoint, and an unauthenticated document endpoint would hand that over whether or not the
    # UI that reads it is protected.
    mount Rswag::Api::Engine => "/openapi", :as => :rswag_api
    mount Rswag::Ui::Engine => "/", :as => :rswag_ui
  end
end
