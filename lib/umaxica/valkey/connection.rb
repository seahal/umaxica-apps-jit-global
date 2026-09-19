# typed: false
# frozen_string_literal: true

require "redis"
require "hiredis-client"
require "active_support/core_ext/object/blank"

module Umaxica
  module Valkey
    # The only application-owned entry point for auth-state Valkey commands. Higher-level stores
    # use this adapter rather than constructing Redis clients or issuing commands themselves.
    class Connection
      public

      def initialize(url: nil, namespace:, client: nil)
        raise ConfigurationError, "Valkey namespace is required" if namespace.to_s.blank?

        @namespace = namespace.to_s
        @url = (url.presence || Settings.current.auth_state.url).to_s
        raise ConfigurationError, "auth-state Valkey URL is required" if @url.blank?

        @client = client || build_client(@url)
      rescue ArgumentError, URI::InvalidURIError => e
        raise ConfigurationError, "invalid Valkey configuration", cause: e
      end

      attr_reader :namespace, :url

      def key(suffix)
        value = suffix.to_s
        raise ConfigurationError, "Valkey key suffix is blank" if value.blank?
        raise ConfigurationError, "Valkey key suffix contains a separator" if value.include?(" ")

        "#{namespace}:#{value}"
      end

      def call(command, *)
        forbid_flush!(command)
        @client.call(command, *)
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Unavailable, "Valkey operation unavailable", cause: e
      end

      def close
        @client.close if @client.respond_to?(:close)
      rescue Redis::BaseError, IOError, SystemCallError
        nil
      end

      def driver_class
        inner = @client.instance_variable_get(:@client)
        config = inner&.config || @client.instance_variable_get(:@config)
        config&.driver
      rescue StandardError
        nil
      end

      def hiredis_driver?
        driver = driver_class
        return false if driver.nil?

        driver.to_s.include?("Hiredis") || driver.name.to_s.include?("Hiredis")
      end

      private

      def build_client(url)
        Redis.new(url: url, driver: :hiredis)
      end

      def forbid_flush!(command)
        name = command.to_s.upcase
        return unless name.in?(%w(FLUSHALL FLUSHDB))

        raise OperationError, "Valkey FLUSH commands are forbidden"
      end
    end
  end
end
