# typed: false
# frozen_string_literal: true

require "uri"

module Umaxica
  module Valkey
    # Parses Redis/Valkey URLs. Expected nonprod DB indexes come from config/valkey.yml
    # via Settings.logical_db — they are not duplicated here.
    module ResponsibilityUrls
      KNOWN = %i(cache rate_limit auth_state performance coverband).freeze

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
              "unknown Valkey responsibility: #{responsibility.inspect}" unless KNOWN.include?(responsibility)
        raise ConfigurationError, "Valkey URL is blank" if url.to_s.blank?

        uri = URI.parse(url.to_s)
        unless %w(redis rediss).include?(uri.scheme)
          raise ConfigurationError, "Valkey URL must use redis or rediss"
        end
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
        Settings.logical_db(responsibility, rails_env: env)
      end

      def assert_nonprod_db!(parsed, env: Rails.env)
        return unless %w(development test).include?(env.to_s)

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
