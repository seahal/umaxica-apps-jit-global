# typed: false
# frozen_string_literal: true

# `rswag-api` is a `group :development` gem, required from config/application.rb (it has to be
# loaded before the routing paths are collected). This file only configures it, so everything here
# stays behind the same development guard.
if Rails.env.development?
  require_relative "../../lib/diagnostic_surface_credentials"

  Rswag::Api.configure do |config|
    # The one directory the bundled descriptions live in. Redocly writes here (redocly.yaml),
    # Committee reads here (test/support/openapi_contract.rb), and this serves the same bytes to
    # Swagger UI. Deliberately outside `public/`, which development serves statically and without
    # credentials -- see adr/openapi-bundle-outside-public.md.
    #
    # Rswag::Api::Middleware expands the request path against this root and refuses anything that
    # escapes it, so only the three bundles are reachable.
    config.openapi_root = Rails.root.join("openapi/bundled").to_s
  end

  # The descriptions enumerate every internal JSON endpoint, its parameters, and its response
  # shapes. This mount is guarded independently of the UI mount: an unauthenticated document
  # endpoint hands that inventory over whether or not the UI that reads it is protected.
  #
  # The check lives in the engine's own middleware stack rather than wrapping the engine at the
  # mount point (config/routes/pghero.rb explains why: a wrapped engine is no longer recognised as
  # a Rails app by `mount`, which then hands it a mount-relative PATH_INFO its own route set never
  # matches, so every request 404s past the engine).
  Rswag::Api::Engine.middleware.use(
    Rack::Auth::Basic,
    "Swagger",
    &DiagnosticSurfaceCredentials.guard(user_key: :SWAGGER_USERNAME, password_key: :SWAGGER_PASSWORD)
  )
end
