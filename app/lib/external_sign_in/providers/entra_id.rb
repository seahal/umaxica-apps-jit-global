# typed: false
# frozen_string_literal: true

require "jwt"

module ExternalSignIn
  module Providers
    # Verifies a Microsoft Entra ID OIDC ID token and returns a NormalizedAuthResult.
    #
    # Raises VerificationError if the token is invalid, expired, has a nonce mismatch,
    # wrong issuer/audience, or contains a non-UUID tid/oid.
    #
    # Keys are resolved via EntraJwksCache (JWKS, RS256 only).
    # Lookup key used downstream: NormalizedAuthResult#tenant_id + #object_id (tid + oid).
    # Evidence fields (iss, sub) are captured for audit; never used for auth lookup.
    class EntraId
      class VerificationError < StandardError
        attr_reader :reason

        def initialize(reason)
          super
          @reason = reason
        end
      end

      ISSUER_TEMPLATE = "https://login.microsoftonline.com/%s/v2.0"
      MICROSOFT_CONSUMER_TENANT_ID = "9188040d-6c67-4c5b-b112-36a304b66dad"
      ALLOWED_ALGORITHMS = ["RS256"].freeze
      MAX_TOKEN_AGE = 10.minutes
      CLOCK_SKEW = 60.seconds
      UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
      private_constant :UUID_FORMAT

      # jwks_loader: injectable for testing; defaults to EntraJwksCache#loader in production.
      def initialize(id_token:, expected_nonce:, expected_tenant_id:, client_id:, jwks_loader: nil, clock: -> {
        Time.current
      })
        @id_token = id_token
        @expected_nonce = expected_nonce
        @expected_tenant_id = expected_tenant_id
        @client_id = client_id
        @jwks_loader = jwks_loader
        @clock = clock
      end

      def call
        fail!("missing_id_token") if id_token.blank?
        fail!("missing_nonce") if expected_nonce.blank?
        fail!("invalid_tenant_id") unless valid_uuid?(expected_tenant_id)
        fail!("personal_account_tenant") if expected_tenant_id.casecmp?(MICROSOFT_CONSUMER_TENANT_ID)

        payload = decode_token
        verify_nonce!(payload)
        verify_tid!(payload)
        verify_oid!(payload)
        verify_sub!(payload)
        verify_token_version!(payload)
        verify_member_account!(payload)
        verify_time_claims!(payload)

        NormalizedAuthResult.new(
          tenant_id: payload["tid"],
          entra_object_id: payload["oid"],
          evidence_issuer: payload["iss"],
          evidence_subject: payload["sub"],
        )
      rescue VerificationError
        raise
      rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError,
             ArgumentError, TypeError, KeyError
        raise VerificationError.new("token_decode_failed")
      rescue EntraJwksCache::FetchError
        raise VerificationError.new("jwks_fetch_failed")
      end

      private

      attr_reader :id_token, :expected_nonce, :expected_tenant_id, :client_id

      def decode_token
        loader = @jwks_loader || EntraJwksCache.new(tenant_id: expected_tenant_id).loader
        payload, _header = JWT.decode(
          id_token,
          nil,
          true,
          algorithms: ALLOWED_ALGORITHMS,
          jwks: loader,
          iss: expected_issuer,
          verify_iss: true,
          aud: client_id,
          verify_aud: true,
          verify_not_before: false,
        )
        payload
      end

      def verify_nonce!(payload)
        nonce = payload["nonce"].to_s
        fail!("nonce_mismatch") unless secure_equal?(nonce, expected_nonce)
      end

      def verify_tid!(payload)
        tid = payload["tid"].to_s
        fail!("tid_missing") if tid.blank?
        fail!("tid_mismatch") unless secure_equal?(tid, expected_tenant_id)
      end

      def verify_oid!(payload)
        oid = payload["oid"].to_s
        fail!("oid_missing") if oid.blank?
        fail!("oid_invalid_format") unless valid_uuid?(oid)
      end

      def verify_sub!(payload)
        fail!("sub_missing") if payload["sub"].to_s.blank?
      end

      def verify_token_version!(payload)
        fail!("token_version_invalid") unless payload["ver"] == "2.0"
      end

      def verify_member_account!(payload)
        fail!("account_type_missing") unless payload.key?("acct")
        fail!("guest_account_not_allowed") unless payload["acct"].to_s == "0"
      end

      def verify_time_claims!(payload)
        now = @clock.call.to_i
        expires_at = integer_claim(payload, "exp", required: true)
        fail!("exp_invalid") if expires_at <= now
        issued_at = integer_claim(payload, "iat", required: true)
        fail!("iat_invalid") if issued_at > now + CLOCK_SKEW || issued_at < now - MAX_TOKEN_AGE

        not_before = integer_claim(payload, "nbf", required: false)
        fail!("nbf_invalid") if not_before && not_before > now + CLOCK_SKEW
      end

      def integer_claim(payload, name, required:)
        value = payload[name]
        fail!("#{name}_missing") if required && value.nil?
        return if value.nil?

        Integer(value)
      rescue ArgumentError, TypeError
        fail!("#{name}_invalid")
      end

      def expected_issuer
        format(ISSUER_TEMPLATE, expected_tenant_id)
      end

      def secure_equal?(lhs, rhs)
        lhs = lhs.to_s
        rhs = rhs.to_s
        return false if lhs.bytesize != rhs.bytesize

        ActiveSupport::SecurityUtils.secure_compare(lhs, rhs)
      end

      def valid_uuid?(value)
        value.to_s.match?(UUID_FORMAT)
      end

      def fail!(reason)
        raise VerificationError.new(reason)
      end
    end
  end
end
