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
        authentication_handoff authentication_result
        invitation_handoff invitation_result
        step_up_handoff step_up_result
        reauthentication_handoff reauthentication_result
        local_sign_in local_sign_up
        local_sign_in_result
      ).freeze
      BINDING_FIELDS = %w(
        actor_type surface subject_ref base_session_ref ceremony_session_ref
      ).freeze
      STATES = %w(issued consumed).freeze
      FIELDS = %w(
        version purpose state actor_type surface subject_ref base_session_ref
        ceremony_session_ref reference result_generation issued_at expires_at consumed_at
      ).freeze

      ConsumeResult =
        Data.define(:status, :payload) do
          def success? = status == :consumed

          def replay? = status == :replay

          def missing? = status == :missing

          def binding_mismatch? = status == :binding_mismatch
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
        local expected_ok, expected = pcall(cjson.decode, ARGV[3])
        if not expected_ok or type(expected) ~= "table" then
          return {"corrupt", ""}
        end
        for key, value in pairs(expected) do
          if payload[key] ~= value then
            return {"binding_mismatch", ""}
          end
        end
        payload["state"] = "consumed"
        payload["consumed_at"] = ARGV[1]
        local ttl = tonumber(ARGV[2])
        redis.call("SET", KEYS[1], cjson.encode(payload), "XX", "EX", ttl)
        return {"consumed", cjson.encode(payload)}
      LUA

      CONSUME_REFERENCE_SCRIPT = <<~LUA.freeze
        local pointer = redis.call("GET", KEYS[1])
        if not pointer then
          return {"missing", ""}
        end
        local pointer_ok, pointer_payload = pcall(cjson.decode, pointer)
        if not pointer_ok or type(pointer_payload) ~= "table" then
          return {"corrupt", ""}
        end
        local current = redis.call("GET", pointer_payload["primary_key"])
        if not current then
          return {"missing", ""}
        end
        local ok, payload = pcall(cjson.decode, current)
        if not ok or type(payload) ~= "table" then
          return {"corrupt", ""}
        end
        local purposes_ok, purposes = pcall(cjson.decode, ARGV[4])
        if not purposes_ok or type(purposes) ~= "table" then
          return {"corrupt", ""}
        end
        local purpose_allowed = false
        for _, purpose in ipairs(purposes) do
          if payload["purpose"] == purpose then
            purpose_allowed = true
            break
          end
        end
        if not purpose_allowed then
          return {"binding_mismatch", ""}
        end
        if payload["state"] ~= "issued" then
          return {"replay", current}
        end
        local expected_ok, expected = pcall(cjson.decode, ARGV[3])
        if not expected_ok or type(expected) ~= "table" then
          return {"corrupt", ""}
        end
        for key, value in pairs(expected) do
          if payload[key] ~= value then
            return {"binding_mismatch", ""}
          end
        end
        payload["state"] = "consumed"
        payload["consumed_at"] = ARGV[1]
        local ttl = tonumber(ARGV[2])
        redis.call("SET", pointer_payload["primary_key"], cjson.encode(payload), "XX", "EX", ttl)
        return {"consumed", cjson.encode(payload)}
      LUA

      public

      def initialize(connection: default_connection)
        @connection = connection
      end

      def issue!(purpose:, actor_type:, surface:, subject_ref: nil, base_session_ref: nil,
                 ceremony_session_ref: nil, reference: nil, result_generation: nil, raw_code: nil,
                 ttl: CODE_TTL, now: Time.current)
        purpose = purpose.to_s
        raise ArgumentError, "unsupported admission purpose" unless PURPOSES.include?(purpose)

        raw = raw_code.to_s.presence || SecureRandom.urlsafe_base64(CODE_BYTES, padding: false)
        reference = reference.to_s.presence || SecureRandom.uuid
        raise ArgumentError, "admission reference is blank" if reference.blank?

        digest = self.class.digest_for(purpose:, raw_code: raw)
        key = @connection.key("admission:#{purpose}:#{digest}")
        reference_key = reference_storage_key(reference)
        payload = {
          "version" => VERSION,
          "purpose" => purpose,
          "state" => "issued",
          "actor_type" => actor_type.to_s,
          "surface" => surface.to_s,
          "subject_ref" => subject_ref.to_s.presence,
          "base_session_ref" => base_session_ref.to_s.presence,
          "ceremony_session_ref" => ceremony_session_ref.to_s.presence,
          "reference" => reference,
          "result_generation" => result_generation,
          "issued_at" => now.iso8601,
          "expires_at" => (now + ttl).iso8601,
        }.compact
        stored = @connection.call(
          "EVAL",
          ISSUE_SCRIPT,
          2,
          key,
          reference_key,
          JSON.generate(payload),
          JSON.generate({ "primary_key" => key, "purpose" => purpose }),
          ttl.to_i,
        )
        raise Umaxica::Valkey::OperationError, "admission code key collision" unless stored == "OK"

        raw
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey admission issue unavailable", cause: e
      end

      def read(raw_code, purpose: "authentication_result")
        encoded = @connection.call("GET", storage_key(purpose, raw_code))
        return nil if encoded.blank?

        JSON.parse(encoded)
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey admission read unavailable", cause: e
      rescue JSON::ParserError => e
        raise Umaxica::Valkey::SerializationError, "admission payload is corrupt", cause: e
      end

      def digest_for(purpose:, raw_code:)
        self.class.digest_for(purpose:, raw_code:)
      end

      def self.digest_for(purpose:, raw_code:)
        Digest::SHA256.hexdigest("#{purpose}:#{raw_code}")
      end
      public_class_method :digest_for

      def consume!(purpose:, raw_code:, expected: {}, now: Time.current, tombstone_ttl: CODE_TTL)
        expected = normalize_expected(expected)
        key = storage_key(purpose, raw_code)
        result = @connection.call(
          "EVAL",
          CONSUME_SCRIPT,
          1,
          key,
          now.iso8601,
          Integer(tombstone_ttl.to_i),
          JSON.generate(expected),
        )
        status = result.is_a?(Array) ? result[0].to_s : "corrupt"
        encoded = result.is_a?(Array) ? result[1] : nil
        payload = encoded.to_s.blank? ? nil : JSON.parse(encoded)
        accepted_statuses = %w(consumed replay missing binding_mismatch)
        return ConsumeResult.new(status: status.to_sym, payload: payload) if accepted_statuses.include?(status)

        raise Umaxica::Valkey::SerializationError, "admission payload is corrupt"
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey admission consume unavailable", cause: e
      end

      def consume_reference!(reference:, expected: {}, purposes: PURPOSES, now: Time.current,
                             tombstone_ttl: CODE_TTL)
        expected = normalize_expected(expected)
        purposes = Array(purposes).map(&:to_s)
        purposes.uniq!
        raise ArgumentError, "admission purposes must not be empty" if purposes.empty?

        unsupported = purposes - PURPOSES
        raise ArgumentError, "unsupported admission purpose: #{unsupported.first}" if unsupported.any?

        result = @connection.call(
          "EVAL",
          CONSUME_REFERENCE_SCRIPT,
          1,
          reference_storage_key(reference),
          now.iso8601,
          Integer(tombstone_ttl.to_i),
          JSON.generate(expected),
          JSON.generate(purposes),
        )
        status = result.is_a?(Array) ? result[0].to_s : "corrupt"
        encoded = result.is_a?(Array) ? result[1] : nil
        payload = encoded.to_s.blank? ? nil : JSON.parse(encoded)
        accepted_statuses = %w(consumed replay missing binding_mismatch)
        return ConsumeResult.new(status: status.to_sym, payload: payload) if accepted_statuses.include?(status)

        raise Umaxica::Valkey::SerializationError, "admission payload is corrupt"
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey admission reference consume unavailable", cause: e
      end

      private

      ISSUE_SCRIPT = <<~LUA.freeze
        if redis.call("EXISTS", KEYS[1]) == 1 or redis.call("EXISTS", KEYS[2]) == 1 then
          return "collision"
        end
        redis.call("SET", KEYS[1], ARGV[1], "EX", ARGV[3])
        redis.call("SET", KEYS[2], ARGV[2], "EX", ARGV[3])
        return "OK"
      LUA

      def default_connection
        Umaxica::Valkey::Connection.new(
          namespace: Umaxica::Valkey::Namespaces.admission(
            **Umaxica::Valkey::Namespaces.runtime_scope,
          ),
        )
      end

      def storage_key(purpose, raw_code)
        raise ArgumentError, "admission code is blank" if raw_code.to_s.blank?

        digest = self.class.digest_for(purpose:, raw_code: raw_code)
        @connection.key("admission:#{purpose}:#{digest}")
      end

      def reference_storage_key(reference)
        reference = reference.to_s
        raise ArgumentError, "admission reference is blank" if reference.blank?

        digest = Digest::SHA256.hexdigest("reference:#{reference}")
        @connection.key("admission-reference:#{digest}")
      end

      def normalize_expected(expected)
        unless expected.respond_to?(:each_pair)
          raise ArgumentError, "admission binding expectations must be a Hash"
        end

        expected.each_with_object({}) do |(key, value), normalized|
          key = key.to_s
          unless BINDING_FIELDS.include?(key)
            raise ArgumentError, "unsupported admission binding field: #{key}"
          end

          normalized[key] = value.to_s
        end
      end
    end
  end
end
