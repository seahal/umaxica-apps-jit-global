# typed: false
# frozen_string_literal: true

module Umaxica
  module Valkey
    # Resolves and validates the complete test Valkey target before any responsibility connects.
    module TestTarget
      URL_NAMES = {
        cache: "CACHE_REDIS_URL",
        rate_limit: "RATE_LIMIT_REDIS_URL",
        auth_state: "AUTH_STATE_REDIS_URL",
      }.freeze

      module_function

      def parse!(environment: ENV, env: "test")
        expected_host = required(environment, "VALKEY_TEST_HOST")
        expected_port = parse_port(required(environment, "VALKEY_TEST_PORT"))
        parsed =
          URL_NAMES.to_h do |responsibility, variable|
            url = required(environment, variable)
            value = ResponsibilityUrls.parse(url, responsibility:)
            ResponsibilityUrls.assert_nonprod_db!(value, env:)
            [responsibility, value]
          end

        parsed.each_value do |value|
          unless value.host == expected_host && value.port == expected_port
            raise ConfigurationError,
                  "#{value.responsibility} Valkey URL is outside VALKEY_TEST_HOST/PORT"
          end
        end
        parsed
      end

      def required(environment, name)
        value = environment.fetch(name).to_s
        raise ConfigurationError, "#{name} is required" if value.empty?

        value
      rescue KeyError => e
        raise ConfigurationError, "#{name} is required", cause: e
      end

      def parse_port(value)
        port = value.is_a?(Integer) ? value : Integer(value.to_s, 10)
        raise ConfigurationError, "VALKEY_TEST_PORT must be between 1 and 65535" unless port.between?(1, 65_535)

        port
      rescue ArgumentError, TypeError => e
        raise ConfigurationError, "VALKEY_TEST_PORT must be an integer", cause: e
      end
    end
  end
end
