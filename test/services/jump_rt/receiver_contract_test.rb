# frozen_string_literal: true

require "test_helper"

# Runs Jump's shared receiver contract (test/fixtures/receiver-contract.json in the Jump
# repository, copied verbatim to test/fixtures/files/jump_receiver_contract.json) against the real
# JumpRtReturnVerifier. Each url_case's literal rt value "returned" is replaced with a Jump-signed
# token whose url claim is the case's signed_url, so the signature, claim, and URL checks all run.
class JumpRtReceiverContractTest < ActiveSupport::TestCase
  CONTRACT = JSON.parse(Rails.root.join("test/fixtures/files/jump_receiver_contract.json").read).freeze

  self.fixture_table_names = []

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @public_jwk = JWT::JWK.new(@private_key, kid: "jump-test").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    @now = Time.current.change(usec: 0)
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  CONTRACT.fetch("url_cases").each do |url_case|
    test "contract url case #{url_case.fetch("name")} is #{url_case.fetch("accepted") ? "accepted" : "rejected"}" do
      iat = @now.to_i
      payload = {
        schema: 1,
        iss: "https://jump.umaxica.net",
        aud: "https://www.umaxica.app",
        sub: "jump-redirect",
        iat: iat,
        nbf: iat,
        exp: iat + CONTRACT.fetch("ttl_seconds"),
        jti: "jump-contract-jti",
        src: "https://auth.umaxica.app",
        dst: "internal",
        rpl: "reuse",
        url: url_case.fetch("signed_url"),
      }
      token = JWT.encode(payload, @private_key, "ES384", { typ: "JWT", kid: "jump-test" })

      result = JumpRtReturnVerifier.call(
        token: token,
        request_url: url_case.fetch("request_url").gsub("returned", token),
        request_base_url: "https://www.umaxica.app",
        fetcher: -> { { "keys" => [@public_jwk] } },
        now: @now,
      )

      assert_equal url_case.fetch("accepted"), result.success?, result.error
      assert_equal "invalid_url", result.error unless url_case.fetch("accepted")
    end
  end

  test "contract time and size limits match the receiver" do
    assert_equal CONTRACT.fetch("inbound_max_ttl_seconds"), JumpRtReturnVerifier::MAX_RETURN_TTL
    assert_equal CONTRACT.fetch("clock_tolerance_seconds"), JumpRtReturnVerifier::LEEWAY
    assert_equal CONTRACT.fetch("max_token_characters"), JumpRtReturnVerifier::MAX_TOKEN_LENGTH
  end

  test "contract claim and header values match the receiver codec" do
    assert_equal CONTRACT.fetch("schema"), SecurityJwtJumpRtTokenCodec::SCHEMA
    assert_equal CONTRACT.fetch("rpl"), SecurityJwtJumpRtTokenCodec::REPLAY_POLICY
    assert_equal CONTRACT.fetch("sub"), SecurityJwtJumpRtTokenCodec::TOKEN_SUBJECT
    assert_equal CONTRACT.dig("header", "alg"), SecurityJwtJumpRtTokenCodec::ALGORITHM
    assert_equal CONTRACT.dig("header", "typ"), SecurityJwtJumpRtTokenCodec::TOKEN_TYPE
  end
end
