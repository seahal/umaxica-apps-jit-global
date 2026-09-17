# typed: false
# frozen_string_literal: true

require "digest"
require "json"

module Valkey
  module AuthState
    # Purpose-specific Base<->Auth opaque codes. Raw codes never persist; only
    # SHA-256 digests are keyed. Sixty-second TTL; CAS issued -> consumed.
    class OpaqueAdmissionStore
      CODE_BYTES = 32
      CODE_TTL = 60.seconds
      VERSION = 1
      PURPOSES = %w(
        sign_in_handoff sign_in_result
        sign_up_handoff sign_up_result
        step_up_handoff step_up_result
        local_sign_in local_sign_up
      ).freeze
      STATES = %w(issued consumed).freeze
      FIELDS = %w(
        version purpose state actor_type surface subject_ref base_session_ref
        ceremony_session_ref issued_at expires_at consumed_at
      ).freeze

      ConsumeResult =
        Data.define(:status, :payload) do
          def success? = status == :consumed

          def replay? = status == :replay

          def missing? = status == :missing
        end

      CONSUME_SCRIPT = <<~LUA.freeze
        local current = redis.call("GET", KEYS[1])
        if not current then
          return {"missing", ""}
        end
        local ok, payload = pcall(cjson.decode, current)
        if not ok or type(payload) ~= "table" then
          return {"corrupt", ""}
        end
        if payload["state"] ~= "issued" then
          return {"replay", current}
        end
        payload["state"] = "consumed"
        payload["consumed_at"] = ARGV[1]
        local ttl = tonumber(ARGV[2])
        redis.call("SET", KEYS[1], cjson.encode(payload), "XX", "EX", ttl)
        return {"consumed", cjson.encode(payload)}
      LUA

      public

      def initialize(connection: default_connection)
        @connection = connection
      end

      def issue!(purpose:, actor_type:, surface:, subject_ref: nil, base_session_ref: nil,
                 ceremony_session_ref: nil, ttl: CODE_TTL, now: Time.current)
        purpose = purpose.to_s
        raise ArgumentError, "unsupported admission purpose" unless PURPOSES.include?(purpose)

        raw = SecureRandom.urlsafe_base64(CODE_BYTES, padding: false)
        payload = {
          "version" => VERSION,
          "purpose" => purpose,
          "state" => "issued",
          "actor_type" => actor_type.to_s,
          "surface" => surface.to_s,
          "subject_ref" => subject_ref.to_s.presence,
          "base_session_ref" => base_session_ref.to_s.presence,
          "ceremony_session_ref" => ceremony_session_ref.to_s.presence,
          "issued_at" => now.iso8601,
          "expires_at" => (now + ttl).iso8601,
        }.compact
        key = storage_key(purpose, raw)
        stored = @connection.call("SET", key, JSON.generate(payload), "NX", "EX", ttl.to_i)
        raise Umaxica::Valkey::OperationError, "admission code key collision" unless stored == "OK"

        raw
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey admission issue unavailable", cause: e
      end

      def consume!(purpose:, raw_code:, now: Time.current, tombstone_ttl: CODE_TTL)
        key = storage_key(purpose, raw_code)
        result = @connection.call("EVAL", CONSUME_SCRIPT, 1, key, now.iso8601, Integer(tombstone_ttl.to_i))
        status = result.is_a?(Array) ? result[0].to_s : "corrupt"
        encoded = result.is_a?(Array) ? result[1] : nil
        payload = encoded.to_s.blank? ? nil : JSON.parse(encoded)
        return ConsumeResult.new(status: status.to_sym, payload: payload) if %w(consumed replay
                                                                                missing).include?(status)

        raise Umaxica::Valkey::SerializationError, "admission payload is corrupt"
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey admission consume unavailable", cause: e
      end

      private

      def default_connection
        Umaxica::Valkey::Connection.new(
          namespace: Umaxica::Valkey::Namespaces.admission(
            **Umaxica::Valkey::Namespaces.runtime_scope,
          ),
        )
      end

      def storage_key(purpose, raw_code)
        raise ArgumentError, "admission code is blank" if raw_code.to_s.blank?

        digest = Digest::SHA256.hexdigest("#{purpose}:#{raw_code}")
        @connection.key("admission:#{purpose}:#{digest}")
      end
    end
  end
end
