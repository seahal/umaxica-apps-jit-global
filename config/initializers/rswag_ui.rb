# typed: false
# frozen_string_literal: true

# `rswag-ui` is a `group :development` gem, required from config/application.rb (it has to be
# loaded before the routing paths are collected). This file only configures it, so everything here
# stays behind the same development guard.
if Rails.env.development?
  require_relative "../../lib/diagnostic_surface_credentials"

  Rswag::Ui.configure do |config|
    # Rswag::Ui::Middleware renders lib/rswag/ui/index.erb with `config_object.to_json` inlined
    # into the `SwaggerUIBundle({...})` call, so every key set here reaches Swagger UI directly.

    # The three surfaces, as relative paths under this same host. `config/routes/swagger.rb` mounts
    # Rswag::Api::Engine at /openapi, so these resolve to the authenticated document endpoint on
    # swagger.umaxica.dev and nowhere else. Relative on purpose: an absolute URL would hard-code an
    # origin, and the browser is already on the canonical one. Adding a fourth entry pointing at
    # any other origin would make Swagger UI fetch an OpenAPI document this repository does not
    # control.
    config.openapi_endpoint "/openapi/openapi.app.yml", "Umaxica app surface"
    config.openapi_endpoint "/openapi/openapi.com.yml", "Umaxica com surface"
    config.openapi_endpoint "/openapi/openapi.org.yml", "Umaxica org surface"

    # Read-only. An empty `supportedSubmitMethods` removes the "Try it out" control for every HTTP
    # method, so the page cannot be used to issue requests against the described APIs. This is the
    # initial posture on purpose: enabling it would mean a dashboard host could drive authenticated
    # calls into the app, org, and com surfaces, which is a separate authorization decision.
    config.config_object[:supportedSubmitMethods] = []

    # Never keep entered credentials in browser storage. With submission disabled there is nothing
    # to authorize, but the default is `false` only by omission -- state it, so enabling
    # submissions later does not silently start persisting secrets.
    config.config_object[:persistAuthorization] = false

    # Reject configuration supplied through the query string. Left enabled, `?url=...` lets anyone
    # with a link make this page load and render an arbitrary remote OpenAPI document.
    config.config_object[:queryConfigEnabled] = false

    # `null` disables Swagger UI's online validator badge. The default posts the description to
    # validator.swagger.io, which would send this application's complete internal API inventory to
    # a third party on every page view.
    config.config_object[:validatorUrl] = nil

    # rswag-ui's own basic_auth_enabled/basic_auth_credentials are deliberately unused: they store
    # the password in `config_object`, which is serialised into the rendered HTML. The guard below
    # keeps the credential in the middleware stack instead.
  end

  # Same fail-closed Rack::Auth::Basic as every other mounted dashboard, in the engine's own
  # middleware stack rather than wrapping the mount (config/routes/pghero.rb explains why).
  Rswag::Ui::Engine.middleware.use(
    Rack::Auth::Basic,
    "Swagger",
    &DiagnosticSurfaceCredentials.guard(user_key: :SWAGGER_USERNAME, password_key: :SWAGGER_PASSWORD)
  )
end
