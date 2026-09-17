# typed: false
# frozen_string_literal: true

require "uri"

module Umaxica
  module Valkey
    # Parses and validates responsibility Redis/Valkey URLs for nonprod logical DB layout.
    module ResponsibilityUrls
      # `performance` and `coverband` back the development-only diagnostic dashboards
      # (config/initializers/rails_performance.rb, config/coverband.rb). They get their own logical
      # databases rather than sharing one behind key prefixes for two reasons beyond tidiness:
      #
      #   - rails_performance reads with `redis.keys("performance|*")`
      #     (RailsPerformance::Utils.fetch_from_redis), an O(keyspace) blocking scan. Confined to
      #     its own database it can only stall its own data, never the cache, the rate-limit
      #     counters, or auth state.
      #   - each writes one key per observed event with its own expiry policy, so a FLUSHDB during
      #     development triage stays scoped to the dashboard being triaged.
      #
      # Nothing authoritative lives in either: both hold derived observability data that is
      # reconstructed by the next request.
      DEV_DBS = {
        cache: 0,
        rate_limit: 1,
        auth_state: 2,
        performance: 6,
        coverband: 7,
      }.freeze
      # The diagnostic gems are `group :development` only, so nothing connects to these two in
      # test. They are declared anyway: `assert_nonprod_db!` refuses to validate a responsibility
      # it has no expected database for, and a silently unvalidated URL is exactly the failure this
      # module exists to prevent.
      TEST_DBS = {
        cache: 3,
        rate_limit: 4,
        auth_state: 5,
        performance: 8,
        coverband: 9,
      }.freeze

      Parsed =
        Data.define(:responsibility, :url, :db, :host, :port) do
          def redis_scheme?
            url.start_with?("redis://", "rediss://")
          end
        end

      module_function

      def parse(url, responsibility:)
        responsibility = responsibility.to_sym
        raise ConfigurationError,
              "unknown Valkey responsibility: #{responsibility.inspect}" unless DEV_DBS.key?(responsibility)
        raise ConfigurationError, "Valkey URL is blank" if url.to_s.blank?

        uri = URI.parse(url.to_s)
        raise ConfigurationError, "Valkey URL must use redis or rediss" unless uri.scheme.in?(%w(redis rediss))
        raise ConfigurationError, "Valkey URL host is blank" if uri.host.blank?

        db = extract_db(uri)
        Parsed.new(
          responsibility: responsibility,
          url: url.to_s,
          db: db,
          host: uri.host,
          port: uri.port || 6379,
        )
      rescue URI::InvalidURIError => e
        raise ConfigurationError, "invalid Valkey URL", cause: e
      end

      # Resolves a responsibility's URL from the environment, fails closed, and proves it points at
      # the logical database that responsibility owns.
      #
      # One-argument `ENV.fetch` on purpose. Both diagnostic gems default to
      # `redis://127.0.0.1:6379/0` when handed no URL -- that is logical database 0, the cache --
      # so a missing variable would not fail, it would quietly write observability data into the
      # application cache. Nothing downstream would report that; the first symptom would be cache
      # keys nobody wrote. Aborting the boot with the variable's name is the only honest outcome.
      def require_url(responsibility, variable, environment: ENV, env: Rails.env)
        url = environment.fetch(variable)
        raise ConfigurationError, "#{variable} is required" if url.to_s.strip.empty?

        parsed = parse(url, responsibility:)
        assert_nonprod_db!(parsed, env:)
        parsed
      rescue KeyError => e
        raise ConfigurationError, "#{variable} is required", cause: e
      end

      def expected_db(responsibility, env: Rails.env)
        table = (env.to_s == "test") ? TEST_DBS : DEV_DBS
        table.fetch(responsibility.to_sym)
      end

      def assert_nonprod_db!(parsed, env: Rails.env)
        return unless env.to_s.in?(%w(development test))

        expected = expected_db(parsed.responsibility, env: env)
        return if parsed.db == expected

        raise ConfigurationError,
              "#{parsed.responsibility} Valkey URL DB is #{parsed.db}, expected #{expected} in #{env}"
      end

      def extract_db(uri)
        path = uri.path.to_s.delete_prefix("/")
        return 0 if path.blank?

        Integer(path)
      rescue ArgumentError => e
        raise ConfigurationError, "Valkey URL DB index is invalid", cause: e
      end
    end
  end
end
