# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SecurityJwtAuthAccessTokenCodecCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "encode rejects blank inputs and accepts a stubbed success path" do
    assert_nil SecurityJwtAuthAccessTokenCodec.encode(nil, host: "app.example.test")
    assert_nil SecurityJwtAuthAccessTokenCodec.encode(
      Client.new(security_mode_id: SecurityModeConfigurable::NORMAL),
      host: "",
    )

    payload = { "sub" => "123", "scope" => "domain:client" }

    AuthorizationTokenClaims.stub(:build, payload) do
      JitSecurityJwtKeyring.stub(:encode, "encoded.jwt") do
        result =
          SecurityJwtAuthAccessTokenCodec.encode(
            Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 123),
            host: "app.example.test",
            resource_type: "client",
            session_public_id: "session-public-id",
          )

        assert_equal "encoded.jwt", result
      end
    end
  end

  test "signed operator access tokens preserve identical scopes for normal and standby" do
    signing_key = OpenSSL::PKey::EC.generate("secp384r1")
    encode_with_test_key =
      lambda do |payload, typ:, issuer_id:|
        JWT.encode(
          payload,
          signing_key,
          SecurityJwtAuthAccessTokenCodec::JWT_ALGORITHM,
          { "typ" => typ, "kid" => "wua6-scope-test" },
        )
      end
    token_arguments = {
      host: "org.example.test",
      resource_type: "operator",
      oidc_sid: "same-session",
      oidc_jti: "same-jti",
      issuer: "https://issuer.example.test",
      audiences: ["https://org.example.test"],
      client_id: "org-browser-client",
    }

    tokens =
      %w(normal standby).map do |context|
        JitSecurityJwtKeyring.stub(:encode, encode_with_test_key) do
          SecurityJwtAuthAccessTokenCodec.encode(
            Operator.new(id: 42),
            **token_arguments,
            authentication_context: context,
          )
        end
      end

    payloads =
      tokens.map do |token|
        JitSecurityJwtKeyring.stub(:public_key_for, signing_key.public_key) do
          SecurityJwtAuthAccessTokenCodec.decode(
            token,
            host: "org.example.test",
            resource_type: "operator",
            issuer: "https://issuer.example.test",
            audiences: ["https://org.example.test"],
            jwt_issuer_id: SecurityJwtAuthAccessTokenCodec::DEFAULT_JWT_ISSUER_ID,
          )
        end
      end

    normal_payload, standby_payload = payloads

    assert_predicate normal_payload, :present?
    assert_predicate standby_payload, :present?
    assert_equal AuthorizationTokenClaims.scopes(normal_payload), AuthorizationTokenClaims.scopes(standby_payload)
    assert_equal %w(authenticated domain:operator read:org write:org),
                 AuthorizationTokenClaims.scopes(normal_payload)
    assert_equal "normal", AuthorizationTokenClaims.authentication_context(normal_payload).to_s
    assert_equal "standby", AuthorizationTokenClaims.authentication_context(standby_payload).to_s
  end

  test "decode_allow_expired returns nil for bad header and success for a stubbed payload" do
    assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired(nil, host: "app.example.test")
    assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired("token", host: nil)

    header = { "kid" => "kid-1" }
    payload = { "sub" => "123", "scope" => "domain:client" }

    JitSecurityJwtKeyring.stub(:parse_header, header) do
      JitSecurityJwtKeyring.stub(:public_key_for, "public-key") do
        JWT.stub(:decode, [payload, header]) do
          SecurityJwtAuthAccessTokenCodec.stub(:valid_header?, true) do
            SecurityJwtRfc9068AccessTokenProfile.stub(:claims_structurally_valid?, true) do
              result =
                SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
                  "token",
                  host: "app.example.test",
                  resource_type: "client",
                  issuer: "issuer",
                  audiences: ["aud"],
                )

              assert_equal payload, result
            end
          end
        end
      end
    end
  end

  test "decode_allow_expired returns nil when kid lookup fails" do
    header = { "kid" => "kid-missing" }

    JitSecurityJwtKeyring.stub(:parse_header, header) do
      JitSecurityJwtKeyring.stub(:public_key_for, nil) do
        SecurityJwtAuthAccessTokenCodec.stub(:valid_header?, true) do
          assert_nil(
            SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
              "token",
              host: "app.example.test",
              resource_type: "client",
            ),
          )
        end
      end
    end
  end

  test "decode reports a payload actor mismatch" do
    header = { "kid" => "kid-1" }
    payload = { "sub" => "123", "scope" => "domain:operator" }

    JitSecurityJwtKeyring.stub(:parse_header, header) do
      JitSecurityJwtKeyring.stub(:public_key_for, "public-key") do
        JWT.stub(:decode, [payload, header]) do
          SecurityJwtAuthAccessTokenCodec.stub(:valid_header?, true) do
            assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
              "token", host: "app.example.test", resource_type: "client",
            )
          end
        end
      end
    end
  end

  test "resource_type_scope_matches? accepts valid actors and rejects invalid ones" do
    assert_not SecurityJwtAuthAccessTokenCodec.resource_type_scope_matches?(nil, "client")
    assert_not SecurityJwtAuthAccessTokenCodec.resource_type_scope_matches?({}, "client")
    assert_not SecurityJwtAuthAccessTokenCodec.resource_type_scope_matches?({ "scope" => "domain:invalid" }, "client")
    assert SecurityJwtAuthAccessTokenCodec.resource_type_scope_matches?({ "scope" => "domain:client" }, "client")
  end

  test "claim extraction helpers delegate to authorization claims" do
    payload = {
      "sub" => "subject-1",
      "scope" => "domain:client openid profile",
      "sid" => "session-1",
      "jti" => "token-1",
    }

    assert_equal "subject-1", SecurityJwtAuthAccessTokenCodec.extract_subject(payload)
    assert_equal "client", SecurityJwtAuthAccessTokenCodec.extract_resource_type(payload)
    assert_equal "session-1", SecurityJwtAuthAccessTokenCodec.extract_session_id(payload)
    assert_equal "token-1", SecurityJwtAuthAccessTokenCodec.extract_jti(payload)
    assert_equal %w(domain:client openid profile), SecurityJwtAuthAccessTokenCodec.extract_scopes(payload)
    assert SecurityJwtAuthAccessTokenCodec.has_scope?(payload, :profile)
    assert_not SecurityJwtAuthAccessTokenCodec.has_scope?(payload, :email)
  end

  test "rejects a correctly signed token when iat is missing" do
    private_key = OpenSSL::PKey::EC.generate("secp384r1")
    payload = {
      "iss" => "issuer",
      "aud" => "audience",
      "exp" => 2.minutes.from_now.to_i,
      "nbf" => Time.current.to_i,
      "sub" => "subject",
      "sid" => "session",
      "client_id" => "umaxica-web-client",
      "jti" => "jti",
      "acr" => "aal1",
      "scope" => "authenticated domain:client",
    }
    token = JWT.encode(payload, private_key, "ES384", { "typ" => "at+jwt", "kid" => "kid" })

    JitSecurityJwtKeyring.stub(:public_key_for, private_key.public_key) do
      assert_nil SecurityJwtAuthAccessTokenCodec.decode(
        token,
        host: "app.example.test",
        resource_type: "client",
        issuer: "issuer",
        audiences: ["audience"],
      )
    end
  end
end
