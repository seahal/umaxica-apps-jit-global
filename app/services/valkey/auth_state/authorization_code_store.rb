# typed: false
# frozen_string_literal: true

require "digest"
require "json"

module Valkey
  module AuthState
    class AuthorizationCodeStore
      CODE_BYTES = 32
      CODE_TTL = 10.seconds
      VERSION = 1
      STATES = %w(issued consumed).freeze
      FIELDS = %w(
        version state client_id redirect_uri subject base_session_ref code_challenge
        code_challenge_method nonce scope auth_time resource_type rp_session_ref
        refresh_family_ref acr amr issued_at expires_at consumed_at replay_detected_at
      ).freeze

      ConsumeResult =
        Data.define(:status, :payload) do
          def success? = status == :consumed

          def replay? = status == :replay

          def missing? = status == :missing

          def mismatch? = status == :mismatch

          def expired? = status == :expired
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
        local now = ARGV[1]
        if payload["expires_at"] and payload["expires_at"] <= now then
          return {"expired", current}
        end
        local expected_count = tonumber(ARGV[2])
        local offset = 3
        for index = 1, expected_count do
          local field = ARGV[offset]
          local expected = ARGV[offset + 1]
          offset = offset + 2
          if tostring(payload[field] or "") ~= expected then
            return {"mismatch", current}
          end
        end
        if payload["state"] ~= "issued" then
          return {"replay", current}
        end
        payload["state"] = "consumed"
        payload["consumed_at"] = now
        local ttl = tonumber(ARGV[offset])
        redis.call("SET", KEYS[1], cjson.encode(payload), "XX", "EX", ttl)
        return {"consumed", cjson.encode(payload)}
      LUA

      LINK_FAMILY_SCRIPT = <<~LUA.freeze
        local current = redis.call("GET", KEYS[1])
        if not current then
          return {"missing", ""}
        end
        local ok, payload = pcall(cjson.decode, current)
        if not ok or type(payload) ~= "table" then
          return {"corrupt", ""}
        end
        if payload["state"] ~= "consumed" then
          return {"invalid_state", current}
        end
        local current_rp = tostring(payload["rp_session_ref"] or "")
        local current_family = tostring(payload["refresh_family_ref"] or "")
        local requested_rp = ARGV[1]
        local requested_family = ARGV[2]
        if payload["replay_detected_at"] then
          return {"replay_detected", current}
        end
        if current_rp ~= "" or current_family ~= "" then
          if current_rp == requested_rp and current_family == requested_family then
            return {"linked", current}
          end
          return {"already_linked", current}
        end
        payload["rp_session_ref"] = requested_rp
        if requested_family ~= "" then
          payload["refresh_family_ref"] = requested_family
        end
        local ttl = tonumber(ARGV[3])
        redis.call("SET", KEYS[1], cjson.encode(payload), "XX", "EX", ttl)
        return {"linked", cjson.encode(payload)}
      LUA

      # Marks a verified replay on the consumed tombstone. Running atomically against
      # LINK_FAMILY_SCRIPT closes the consume-to-link gap: a mark that lands first makes
      # the winning exchange's link fail, and a link that lands first is returned here so
      # the caller can revoke the family it names.
      MARK_REPLAY_SCRIPT = <<~LUA.freeze
        local current = redis.call("GET", KEYS[1])
        if not current then
          return {"missing", ""}
        end
        local ok, payload = pcall(cjson.decode, current)
        if not ok or type(payload) ~= "table" then
          return {"corrupt", ""}
        end
        if payload["state"] ~= "consumed" then
          return {"invalid_state", current}
        end
        if not payload["replay_detected_at"] then
          payload["replay_detected_at"] = ARGV[1]
        end
        redis.call("SET", KEYS[1], cjson.encode(payload), "XX", "KEEPTTL")
        return {"marked", cjson.encode(payload)}
      LUA

      public

      def initialize(connection: default_connection)
        @connection = connection
      end

      def issue!(client_id:, redirect_uri:, subject:, code_challenge:, code_challenge_method:, nonce: nil,
                 scope: nil, auth_time: nil, resource_type:, base_session_ref: nil, rp_session_ref: nil,
                 refresh_family_ref: nil, acr: nil, amr: nil, ttl: CODE_TTL, now: Time.current)
        raise ArgumentError, "code_challenge_method must be S256" unless code_challenge_method.to_s == "S256"

        raw_code = SecureRandom.urlsafe_base64(CODE_BYTES, padding: false)
        payload = {
          "version" => VERSION,
          "state" => "issued",
          "client_id" => client_id.to_s,
          "redirect_uri" => redirect_uri.to_s,
          "subject" => subject.to_s,
          "base_session_ref" => base_session_ref.to_s.presence,
          "code_challenge" => code_challenge.to_s,
          "code_challenge_method" => code_challenge_method.to_s,
          "nonce" => nonce.to_s.presence,
          "scope" => scope.to_s.presence,
          "auth_time" => auth_time.respond_to?(:iso8601) ? auth_time.iso8601 : auth_time.to_s.presence,
          "resource_type" => resource_type.to_s,
          "rp_session_ref" => rp_session_ref.to_s.presence,
          "refresh_family_ref" => refresh_family_ref.to_s.presence,
          "acr" => acr.to_s.presence,
          "amr" => amr.to_s.presence,
          "issued_at" => now.iso8601,
          "expires_at" => (now + ttl).iso8601,
        }.compact
        encoded = encode_payload(payload)
        key = storage_key(raw_code)
        # Keep key longer than logical expiry so application-level expires_at checks
        # remain observable under test time travel; Redis TTL is wall-clock cleanup only.
        redis_ttl = [ttl.to_i * 6, 60].max
        stored = @connection.call("SET", key, encoded, "NX", "EX", redis_ttl)
        raise Umaxica::Valkey::OperationError, "authorization code key collision" unless stored == "OK"

        raw_code
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey authorization code issue unavailable", cause: e
      end

      def read(raw_code)
        key = storage_key(raw_code)
        encoded = @connection.call("GET", key)
        return nil if encoded.blank?

        parse_payload(encoded)
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey authorization code read unavailable", cause: e
      end

      def consume!(raw_code:, expected:, tombstone_ttl: nil, now: Time.current)
        key = storage_key(raw_code)
        normalized_expected = normalize_expected(expected)
        ttl = Integer(tombstone_ttl || [CODE_TTL.to_i * 6, 60].max)
        result = @connection.call(
          "EVAL",
          CONSUME_SCRIPT,
          1,
          key,
          now.iso8601,
          normalized_expected.length,
          *normalized_expected.flatten,
          ttl,
        )
        status = result.is_a?(Array) ? result[0].to_s : "corrupt"
        payload = parse_payload(result.is_a?(Array) ? result[1] : nil)
        return ConsumeResult.new(status: status.to_sym, payload: payload) if %w(consumed replay missing
                                                                                mismatch expired).include?(status)

        raise Umaxica::Valkey::SerializationError, "authorization code payload is corrupt" if status == "corrupt"

        raise Umaxica::Valkey::OperationError, "unexpected authorization code status"
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey authorization code consume unavailable", cause: e
      end

      def link_family!(raw_code:, rp_session_ref:, refresh_family_ref: nil, tombstone_ttl: nil)
        key = storage_key(raw_code)
        ttl = Integer(tombstone_ttl || [CODE_TTL.to_i * 6, 60].max)
        result = @connection.call(
          "EVAL",
          LINK_FAMILY_SCRIPT,
          1,
          key,
          rp_session_ref.to_s,
          refresh_family_ref.to_s,
          ttl,
        )
        status = result.is_a?(Array) ? result[0].to_s : "corrupt"
        payload = parse_payload(result.is_a?(Array) ? result[1] : nil)
        return ConsumeResult.new(status: status.to_sym, payload: payload) if %w(linked already_linked missing
                                                                                invalid_state
                                                                                replay_detected).include?(status)

        raise Umaxica::Valkey::SerializationError, "authorization code payload is corrupt" if status == "corrupt"

        raise Umaxica::Valkey::OperationError, "unexpected authorization code link status"
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey authorization code link unavailable", cause: e
      end

      def mark_replay!(raw_code:, now: Time.current)
        result = @connection.call("EVAL", MARK_REPLAY_SCRIPT, 1, storage_key(raw_code), now.iso8601)
        status = result.is_a?(Array) ? result[0].to_s : "corrupt"
        payload = parse_payload(result.is_a?(Array) ? result[1] : nil)
        return ConsumeResult.new(status: status.to_sym, payload: payload) if %w(marked missing
                                                                                invalid_state).include?(status)

        raise Umaxica::Valkey::SerializationError, "authorization code payload is corrupt" if status == "corrupt"

        raise Umaxica::Valkey::OperationError, "unexpected authorization code replay mark status"
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey authorization code replay mark unavailable", cause: e
      end

      def storage_key(raw_code)
        digest = Digest::SHA256.hexdigest(raw_code.to_s)
        raise ArgumentError, "authorization code is blank" if raw_code.to_s.blank?

        @connection.key(digest)
      end

      private

      def default_connection
        namespace = Umaxica::Valkey::Namespaces.authorization_codes(
          **Umaxica::Valkey::Namespaces.runtime_scope,
        )
        Umaxica::Valkey::Connection.new(namespace: namespace)
      end

      def normalize_expected(expected)
        expected.to_h.filter_map do |field, value|
          name = field.to_s
          next unless FIELDS.include?(name)
          next if value.nil?

          [name, value.respond_to?(:iso8601) ? value.iso8601 : value.to_s]
        end
      end

      def encode_payload(payload)
        unknown = payload.keys.map(&:to_s) - FIELDS
        raise Umaxica::Valkey::SerializationError, "authorization code payload has unknown fields" if unknown.any?

        JSON.generate(payload)
      rescue JSON::GeneratorError => e
        raise Umaxica::Valkey::SerializationError, "authorization code payload is not serializable", cause: e
      end

      def parse_payload(encoded)
        return nil if encoded.to_s.blank?

        payload = JSON.parse(encoded)
        raise Umaxica::Valkey::SerializationError,
              "authorization code payload must be an object" unless payload.is_a?(Hash)
        raise Umaxica::Valkey::SerializationError,
              "authorization code payload version mismatch" unless payload["version"] == VERSION
        raise Umaxica::Valkey::SerializationError,
              "authorization code payload state invalid" unless STATES.include?(payload["state"])

        unknown = payload.keys - FIELDS
        raise Umaxica::Valkey::SerializationError, "authorization code payload has unknown fields" if unknown.any?

        payload
      rescue JSON::ParserError => e
        raise Umaxica::Valkey::SerializationError, "authorization code payload is corrupt", cause: e
      end
    end
  end
end
