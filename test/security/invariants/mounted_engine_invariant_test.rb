# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Security
  module Invariants
    # Third-party Rack apps mounted with `mount` bypass the entire application
    # authorization stack: they subclass ActionController::Base (or are bare Rack
    # apps), so AuthenticationBase, enforce_access_policy!, surface isolation, and
    # the per-surface CSRF origin configuration never run for them.
    #
    # This test pins which mounts are allowed to exist outside development, and
    # asserts that engines whose own defaults are unauthenticated are absent.
    class MountedEngineInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      # Engines that self-mount with no authentication by default. Each must be
      # confined to `group :development` in the Gemfile so it is never loaded in
      # test or production.
      #
      # rails_db: config/routes.rb in the gem calls
      #   `Rails.application.routes.draw { mount_rails_db_routes }` whenever
      #   RailsDb.automatic_routes_mount is true (the default), and
      #   RailsDb.verify_access_proc defaults to `proc { |controller| true }`
      #   with http_basic_authentication_enabled = false. Mounted, it exposes
      #   POST /rails/db/execute (arbitrary SQL) and GET /rails/db/tables/:id/truncate.
      UNAUTHENTICATED_ENGINE_CONSTANTS = %w(
        RailsDb
        Blazer
        PgHero
      ).freeze

      # Path prefixes that must not appear in the route set outside development.
      FORBIDDEN_MOUNT_PATHS = %w(
        /rails/db
        /blazer
        /pghero
      ).freeze

      test "unauthenticated admin engines are not loaded outside development" do
        assert_not_predicate Rails.env, :development?,
                             "This invariant is meaningful only outside development; the suite must not run in " \
                             "development."

        UNAUTHENTICATED_ENGINE_CONSTANTS.each do |constant_name|
          assert_not Object.const_defined?(constant_name),
                     "#{constant_name} is loaded in #{Rails.env}. It mounts an unauthenticated interface by default " \
                     "and must stay confined to `group :development` in the Gemfile."
        end
      end

      test "no unauthenticated admin engine path is routable outside development" do
        routed_paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

        FORBIDDEN_MOUNT_PATHS.each do |forbidden_path|
          matches = routed_paths.select { |path| path.start_with?(forbidden_path) }

          assert_empty matches,
                       "#{forbidden_path} is routable in #{Rails.env}: #{matches.inspect}. " \
                       "Mounted admin engines bypass enforce_access_policy! and surface isolation entirely."
        end
      end

      # Every mounted Rack app, with the control that stands in for the application
      # authorization stack it bypasses. Adding an entry here is a security review.
      REVIEWED_MOUNTS = {
        # Rails mounts the ActionCable server by default. The application defines no
        # channels and no Connection class, so there is no reachable subscription.
        "/cable" => "ActionCable::Server::Base",
        # Feature-flag UI on its dedicated hosts (config/routes/flipper.rb). Guarded by
        # Rack::Auth::Basic, which fails closed when credentials are unset.
        "flipper.umaxica.dev /" => "Rack::Auth::Basic",
        "flipper.core.dev.localhost /" => "Rack::Auth::Basic",
        # Solid Queue job-monitoring UI, dedicated host (config/routes/mission.rb). Guarded by
        # MissionControl::Jobs' own HTTP Basic Auth (config/initializers/mission_control_jobs.rb),
        # which fails closed (401) when its credentials are unset. Not loaded in test (the gem is
        # `group :development, :production`), so this entry documents production; it is inert here.
        "mission.core.dev.localhost /" => "MissionControl::Jobs::Engine",
        # SQL exploration dashboard, dedicated host (config/routes/blazer.rb). `blazer` stays a
        # `group :development` gem (Gemfile) even though it is mounted -- it is not loaded outside
        # development, so this entry is inert in test/production and documents development only.
        # Guarded by Rack::Auth::Basic, which fails closed when credentials are unset.
        "blazer.core.dev.localhost /" => "Rack::Auth::Basic",
        # PostgreSQL monitoring dashboard, dedicated host (config/routes/pghero.rb). Same
        # `group :development`-only, mounted-in-dev-only shape as Blazer above.
        "pghero.core.dev.localhost /" => "Rack::Auth::Basic",
      }.freeze

      # Both the Flipper and Mission Control mounts sit at the path root of their own dedicated
      # host, so path alone no longer identifies a mount uniquely; the key folds in the route's
      # host constraint (nil for an unconstrained mount such as /cable).
      def self.mount_key(route) = [route.constraints[:host]&.first, route.path.spec.to_s].compact.join(" ")

      # A directly-mounted Rails::Engine class responds to `.call` as a class method, so its
      # dispatcher's `#app` is the class itself and `.class.name` is always the unhelpful "Class".
      # Rack apps mounted as an instance (Rack::Auth::Basic.new(...), ActionCable.server) keep
      # `.class.name`, which is what actually names the guard.
      def self.mount_identity(endpoint) = endpoint.is_a?(Class) ? endpoint.name : endpoint.class.name

      test "every mounted Rack app is reviewed and carries its own authorization guard" do
        # `mount` produces a route whose endpoint is not the application's own router.
        # Any such route is an authorization blind spot and must be listed above.
        mounted =
          Rails.application.routes.routes.filter_map do |route|
            dispatcher = route.app
            next unless dispatcher.respond_to?(:app)

            endpoint = dispatcher.app
            next if endpoint.is_a?(ActionDispatch::Routing::RouteSet::Dispatcher)
            next unless endpoint.respond_to?(:call)
            next if endpoint.is_a?(Proc)

            [self.class.mount_key(route), self.class.mount_identity(endpoint)]
          end.to_h

        unreviewed = mounted.keys - REVIEWED_MOUNTS.keys

        assert_empty unreviewed,
                     "Unreviewed mounted Rack apps found: #{unreviewed.inspect}. " \
                     "Mounted apps bypass enforce_access_policy! and surface isolation entirely — " \
                     "add an authorization guard, then record it in REVIEWED_MOUNTS."

        REVIEWED_MOUNTS.each do |key, expected_endpoint|
          next unless mounted.key?(key)

          assert_equal expected_endpoint, mounted.fetch(key),
                       "The Rack app mounted at #{key} changed from #{expected_endpoint} to " \
                       "#{mounted.fetch(key)}. If its authorization guard was removed, restore it."
        end
      end

      test "the Flipper UI mount is wrapped in an authorization guard" do
        flipper_route =
          Rails.application.routes.routes.find { |route| route.constraints[:host] == ["flipper.core.dev.localhost"] }

        skip "Flipper UI is not mounted in this environment" if flipper_route.nil?

        endpoint = flipper_route.app.app

        assert_kind_of Rack::Auth::Basic, endpoint,
                       "Flipper::UI must not be mounted bare: it carries no application session guard, " \
                       "so a request reaching the origin directly would get unauthenticated flag read/write."
      end

      test "the Flipper UI guard denies access when credentials are not configured" do
        guard =
          Rack::Auth::Basic.new(->(_env) { [200, {}, ["reached the flag UI"]] }) do |user, password|
            expected_user = Rails.app.creds.option(:FLIPPER_UI_USER)
            expected_password = Rails.app.creds.option(:FLIPPER_UI_PASSWORD)

            if expected_user.blank? || expected_password.blank?
              false
            else
              ActiveSupport::SecurityUtils.secure_compare(user.to_s, expected_user) &
                ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
            end
          end

        env = Rack::MockRequest.env_for("/flipper")
        status, _headers, _body = guard.call(env)

        assert_equal 401, status,
                     "An unauthenticated request must be rejected. A guard that fails open when " \
                     "credentials are unset is worse than no guard, because it reads as protection."
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
