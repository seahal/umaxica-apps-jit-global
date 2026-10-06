# typed: false
# frozen_string_literal: true

require "digest"

module Valkey
  module AuthState
    class OidcRpRefreshCoordinationStore
      LEASE_TTL = 5.seconds
      RESULT_TTL = 5.seconds

      RELEASE_SCRIPT = <<~LUA.freeze
        if redis.call("GET", KEYS[1]) == ARGV[1] then
          return redis.call("DEL", KEYS[1])
        end
        return 0
      LUA

      public

      def initialize(connection: default_connection)
        @connection = connection
      end

      def acquire(resource_type:, rp_session_public_id:, owner:)
        raise ArgumentError, "RP refresh lease owner is required" if owner.to_s.blank?

        result = @connection.call(
          "SET", lease_key(resource_type:, rp_session_public_id:), owner.to_s, "NX", "PX", lease_ttl_milliseconds,
        )
        result == "OK" || result == true
      end

      def publish(resource_type:, rp_session_public_id:, ciphertext:)
        raise ArgumentError, "RP refresh delivery ciphertext is required" if ciphertext.to_s.blank?

        @connection.call(
          "SET", result_key(resource_type:, rp_session_public_id:), ciphertext.to_s, "EX", RESULT_TTL.to_i,
        )
        true
      end

      def read(resource_type:, rp_session_public_id:)
        @connection.call("GET", result_key(resource_type:, rp_session_public_id:)).presence
      end

      def release(resource_type:, rp_session_public_id:, owner:)
        @connection.call(
          "EVAL", RELEASE_SCRIPT, 1, lease_key(resource_type:, rp_session_public_id:), owner.to_s,
        )
        true
      end

      private

      def default_connection
        Umaxica::Valkey::Connection.new(
          namespace: Umaxica::Valkey::Namespaces.rp_refresh(
            **Umaxica::Valkey::Namespaces.runtime_scope,
          ),
        )
      end

      def lease_ttl_milliseconds
        (LEASE_TTL * 1000).to_i
      end

      def lease_key(resource_type:, rp_session_public_id:)
        @connection.key("lease:#{fingerprint(resource_type:, rp_session_public_id:)}")
      end

      def result_key(resource_type:, rp_session_public_id:)
        @connection.key("result:#{fingerprint(resource_type:, rp_session_public_id:)}")
      end

      def fingerprint(resource_type:, rp_session_public_id:)
        Digest::SHA256.hexdigest("#{resource_type}:#{rp_session_public_id}")
      end
    end
  end
end
