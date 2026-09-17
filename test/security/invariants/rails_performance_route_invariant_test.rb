# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Security
  module Invariants
    # `rails_performance` ships one config/routes.rb that does two things:
    #
    #   RailsPerformance::Engine.routes.draw { ...thirteen GET routes... }
    #   Rails.application.routes.draw { mount RailsPerformance::Engine => RailsPerformance.mount_at }
    #
    # The second half has no host constraint and no flag to disable it, so the dashboard would
    # answer on every FQDN this application serves. config/application.rb drops the engine's
    # `config/routes.rb` path to suppress it, which suppresses the first half too --
    # config/routes/performance.rb therefore carries a verbatim copy of the engine's route list,
    # behind the host constraint.
    #
    # A copied gem-internal list drifts on upgrade, silently: a renamed route leaves a dashboard
    # tab that 404s, and a newly added one is simply missing. This test reads the gem's shipped
    # file and fails when the copy no longer matches it.
    #
    # `rails_performance` is a `group :development` gem, so it is absent under RAILS_ENV=test and
    # these assertions skip. That is not a hole: the invariant that matters in test --
    # /rails/performance must not be routable -- is asserted by MountedEngineInvariantTest, which
    # does run here. This test is for the developer who bumps the gem and for any CI job that runs
    # the suite with the development bundle.
    class RailsPerformanceRouteInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      ROUTE_FILE = Rails.root.join("config/routes/performance.rb")

      # Matches `get "/requests" => "rails_performance#requests"` in either file.
      ROUTE_PATTERN = /get\s+"(?<path>[^"]+)"\s*=>\s*"(?<endpoint>[^"]+)"/

      def gem_directory
        spec = Gem.loaded_specs["rails_performance"]
        skip "rails_performance is not loaded in #{Rails.env}; it is a `group :development` gem." if spec.nil?

        spec.gem_dir
      end

      def routes_from(source) = source.scan(ROUTE_PATTERN).to_h.freeze

      test "the mounted route list matches the one the gem ships" do
        gem_routes = routes_from(File.read(File.join(gem_directory, "config/routes.rb")))
        local_routes = routes_from(File.read(ROUTE_FILE))

        assert_not_empty gem_routes,
                         "No routes parsed out of the gem's config/routes.rb. The gem changed shape; " \
                         "re-read it before trusting anything else in this test."

        assert_equal gem_routes, local_routes,
                     "config/routes/performance.rb has drifted from the route list rails_performance " \
                     "ships. Missing here: #{(gem_routes.keys - local_routes.keys).inspect}. Extra " \
                     "here: #{(local_routes.keys - gem_routes.keys).inspect}. Copy the gem's list " \
                     "across; the copy exists only because the gem's own routes file has to stay " \
                     "unloaded to suppress its unconstrained self-mount."
      end

      test "the gem's unconstrained self-mount is suppressed" do
        gem_source = File.read(File.join(gem_directory, "config/routes.rb"))

        assert_match(/Rails\.application\.routes\.draw/, gem_source,
                     "rails_performance no longer self-mounts into the application route set. If the " \
                     "gem gained a supported way to disable or constrain its mount, drop the " \
                     "`paths[\"config/routes.rb\"] = []` workaround in config/application.rb and the " \
                     "copied route list in config/routes/performance.rb, and use it instead.")

        assert_empty RailsPerformance::Engine.paths["config/routes.rb"].existent,
                     "RailsPerformance::Engine still has a routing path, so its config/routes.rb will " \
                     "run and mount the dashboard on every host. config/application.rb must clear it " \
                     "before the add_routing_paths initializer collects it."
      end

      test "the dashboard is reachable only through the performance host" do
        gem_directory # skips unless the gem is loaded, before touching its constants

        performance_mounts =
          Rails.application.routes.routes.select do |route|
            dispatcher = route.app
            dispatcher.respond_to?(:app) && dispatcher.app == RailsPerformance::Engine
          end

        assert_not_empty performance_mounts,
                         "RailsPerformance::Engine is loaded but never mounted, so the dashboard is dead."

        performance_mounts.each do |route|
          hosts = Array(route.constraints[:host])

          assert_not_empty hosts,
                           "RailsPerformance::Engine is mounted with no host constraint at " \
                           "#{route.path.spec}. That is the gem's self-mount reappearing: the dashboard " \
                           "would answer on every FQDN this application serves."
          hosts.each do |host|
            assert_kind_of String, host,
                           "The performance mount is constrained by #{host.inspect}, not an exact " \
                           "hostname string. A Regexp here is how a pattern such as /umaxica\\.dev/ " \
                           "ends up admitting every sibling dashboard host."
          end
        end
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
