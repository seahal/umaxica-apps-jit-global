# typed: false
# frozen_string_literal: true

require_relative "../../lib/diagnostic_surface_credentials"

# Coverband owns the runtime code-execution report (Coverband::Reporters::Web), on its own
# dedicated host. Public canonical host: coverband.umaxica.dev.
# Development host: coverband.core.dev.localhost.
constraints host: [ENV["PUBLIC_COVERBAND_URL"], ENV["PRIVATE_COVERBAND_URL"],
                   "coverband.core.dev.localhost",].compact do
  # `coverband` is a `group :development` gem (Gemfile), and config/application.rb requires it only
  # in the process that serves requests (CoverbandProcessGate). The constant therefore does not
  # exist while running the test suite, in a console, or in a rake task.
  if defined?(Coverband::Reporters::Web)
    # Cloudflare Access fronts coverband.umaxica.dev, but the mounted Rack app must not depend on
    # the edge alone: Coverband::Reporters::Web subclasses nothing of this application, so
    # enforce_access_policy! and surface isolation never run for it, and any request that reached
    # the origin directly would get a file-by-file, line-by-line read of this repository's source
    # along with which parts of it execute -- which is a map of the code paths worth attacking.
    #
    # Wrapped at the mount point rather than pushed into an engine's middleware stack, because this
    # is a plain Rack app and not a Rails engine; the PATH_INFO problem that forces the other
    # dashboards to use engine middleware (config/routes/pghero.rb) does not arise. Same shape as
    # the Flipper UI mount.
    #
    # Fails closed: when the credentials are not configured the block returns false and every
    # request is answered with 401, rather than defaulting to open access.
    mount(
      Rack::Auth::Basic.new(
        Coverband::Reporters::Web.new,
        &DiagnosticSurfaceCredentials.guard(
          user_key: :COVERBAND_USERNAME,
          password_key: :COVERBAND_PASSWORD,
        )
      ).tap { |app| app.realm = "Coverband" } => "/",
      :as => :coverband,
    )
  end
end
