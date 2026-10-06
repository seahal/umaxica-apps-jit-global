# frozen_string_literal: true

require "digest"
require "json"

module Valkey
  module AuthState
    # Holds a signed social result behind a short-lived, non-authorizing receiver
    # reference. The browser carries only the reference to Base; the signed
    # evidence remains in the Auth-state store until the receiver POST reads it.
    class SocialCeremonyResultStore
      TTL = 60.seconds
      VERSION = 1

      public

      def initialize(connection: default_connection)
        @connection = connection
      end

      def issue!(token:, expires_at:, reference: SecureRandom.uuid, now: Time.current)
        ttl = [expires_at.to_time - now, 1.second].max
        payload = JSON.generate(
          "version" => VERSION, "token" => token.to_s, "expires_at" => expires_at.iso8601,
        )
        stored = @connection.call("SET", storage_key(reference), payload, "NX", "EX", ttl.to_i)
        raise Umaxica::Valkey::OperationError, "social result reference collision" unless stored == "OK"

        reference
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey social result issue unavailable", cause: e
      end

      def read(reference:, now: Time.current)
        encoded = @connection.call("GET", storage_key(reference))
        return nil if encoded.to_s.blank?

        payload = JSON.parse(encoded)
        raise Umaxica::Valkey::SerializationError, "social result payload is corrupt" unless
          payload.is_a?(Hash) && payload["version"] == VERSION
        return nil if Time.zone.iso8601(payload.fetch("expires_at")) <= now

        payload.fetch("token")
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey social result read unavailable", cause: e
      rescue JSON::ParserError, KeyError, ArgumentError => e
        raise Umaxica::Valkey::SerializationError, "social result payload is corrupt", cause: e
      end

      private

      def default_connection
        Umaxica::Valkey::Connection.new(
          namespace: Umaxica::Valkey::Namespaces.admission(**Umaxica::Valkey::Namespaces.runtime_scope),
        )
      end

      def storage_key(reference)
        raise ArgumentError, "social result reference is blank" unless
          reference.is_a?(String) && reference.present?

        @connection.key("social-result:#{Digest::SHA256.hexdigest(reference)}")
      end
    end
  end
end
