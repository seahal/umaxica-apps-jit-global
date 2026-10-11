# typed: false
# frozen_string_literal: true

require "digest"
require "json"

module Valkey
  module AuthState
    class SignOutNoticeStore
      TTL = 5.minutes
      VERSION = 1
      FIELDS = %w(version actor_ref face sid expires_at access_expires_at state).freeze

      GETDEL_SCRIPT = <<~LUA.freeze
        local value = redis.call("GET", KEYS[1])
        if value then
          redis.call("DEL", KEYS[1])
        end
        return value or ""
      LUA

      public

      def initialize(connection: default_connection)
        @connection = connection
      end

      def issue!(payload:, ttl: TTL, now: Time.current)
        normalized = normalize_payload(payload, now: now, ttl: ttl)
        raw_id = SecureRandom.urlsafe_base64(32, padding: false)
        stored = @connection.call("SET", storage_key(raw_id), JSON.generate(normalized), "NX", "EX", ttl.to_i)
        raise Umaxica::Valkey::OperationError, "sign-out notice key collision" unless stored == "OK"

        raw_id
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey sign-out notice issue unavailable", cause: e
      end

      def consume(raw_id:, now: Time.current)
        payload = read(raw_id: raw_id, now: now, delete: true)
        payload
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey sign-out notice consume unavailable", cause: e
      rescue ArgumentError, KeyError, TypeError => e
        raise Umaxica::Valkey::SerializationError, "sign-out notice payload is corrupt", cause: e
      end

      def read(raw_id:, now: Time.current, delete: false)
        encoded =
          if delete
            @connection.call("EVAL", GETDEL_SCRIPT, 1, storage_key(raw_id))
          else
            @connection.call("GET", storage_key(raw_id))
          end
        return nil if encoded.to_s.blank?

        payload = parse_payload(encoded)
        expires_at = Time.zone.iso8601(payload.fetch("expires_at"))
        return nil if expires_at <= now

        payload
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey sign-out notice read unavailable", cause: e
      rescue ArgumentError, KeyError, TypeError => e
        raise Umaxica::Valkey::SerializationError, "sign-out notice payload is corrupt", cause: e
      end

      def storage_key(raw_id)
        raise ArgumentError, "sign-out notice id is blank" if raw_id.to_s.blank?

        @connection.key(Digest::SHA256.hexdigest(raw_id.to_s))
      end

      private

      def default_connection
        namespace = Umaxica::Valkey::Namespaces.sign_out_notices(
          **Umaxica::Valkey::Namespaces.runtime_scope,
        )
        Umaxica::Valkey::Connection.new(namespace: namespace)
      end

      def normalize_payload(payload, now:, ttl:)
        value = payload.to_h.stringify_keys
        normalized = {
          "version" => VERSION,
          "actor_ref" => value["actor_ref"].to_s.presence,
          "face" => value["face"].to_s.presence,
          "sid" => value["sid"].to_s.presence,
          "expires_at" => value["expires_at"].presence || (now + ttl).iso8601,
          "access_expires_at" => value["access_expires_at"].presence,
          "state" => value["state"].to_s.presence,
        }.compact
        unknown = normalized.keys - FIELDS
        raise Umaxica::Valkey::SerializationError, "sign-out notice payload has unknown fields" if unknown.any?

        normalized
      end

      def parse_payload(encoded)
        payload = JSON.parse(encoded)
        raise Umaxica::Valkey::SerializationError,
              "sign-out notice payload must be an object" unless payload.is_a?(Hash)
        raise Umaxica::Valkey::SerializationError,
              "sign-out notice version mismatch" unless payload["version"] == VERSION

        unknown = payload.keys - FIELDS
        raise Umaxica::Valkey::SerializationError, "sign-out notice payload has unknown fields" if unknown.any?

        payload
      rescue JSON::ParserError => e
        raise Umaxica::Valkey::SerializationError, "sign-out notice payload is corrupt", cause: e
      end
    end
  end
end
