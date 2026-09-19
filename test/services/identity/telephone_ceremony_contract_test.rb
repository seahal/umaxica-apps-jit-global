# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityTelephoneCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.local(2026, 1, 2, 3, 4, 5)
  end

  teardown do
    travel_back
  end

  test "valid grant serializes and deserializes with sign audience binding" do
    travel_to(@now) do
      token = IdentityTelephoneCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id)

      grant = IdentityTelephoneCeremonyGrant.decode(token, issuer_id: acme_issuer_id)

      assert_equal "telephone_ceremony", grant["purpose"]
      assert_equal "app", grant["surface"]
      assert_equal "registration", grant["operation"]
      assert_equal "actor-client-1", grant["actor_ref"]
      assert_equal "session-1", grant["session_ref"]
      assert_equal "grant-1", grant["jti"]
      assert_equal IdentityTelephoneCeremonyContract.sign_audience("app"), grant["aud"]
      assert_equal JitSecurityJwtKeyring.active_kid(acme_issuer_id), grant.kid
    end
  end

  test "grant rejects missing required actor session and jti fields" do
    assert_contract_error(/missing required claims: actor_ref/) do
      IdentityTelephoneCeremonyGrant.new(valid_grant_claims.except("actor_ref"))
    end

    assert_contract_error(/missing required claims: session_ref/) do
      IdentityTelephoneCeremonyGrant.new(valid_grant_claims.merge("session_ref" => ""))
    end

    assert_contract_error(/missing required claims: jti/) do
      IdentityTelephoneCeremonyGrant.new(valid_grant_claims.except("jti"))
    end
  end

  test "grant rejects expired wrong audience wrong purpose wrong surface and wrong operation" do
    travel_to(@now) do
      assert_contract_error(/exp is expired/) do
        IdentityTelephoneCeremonyGrant.new(valid_grant_claims.merge("exp" => 1.second.ago.to_i))
      end

      assert_contract_error(/aud is invalid/) do
        IdentityTelephoneCeremonyGrant.new(valid_grant_claims.merge("aud" => "https://evil.example"))
      end

      assert_contract_error(/purpose is invalid/) do
        IdentityTelephoneCeremonyGrant.new(valid_grant_claims.merge("purpose" => "wrong"))
      end

      assert_contract_error(/surface is invalid/) do
        IdentityTelephoneCeremonyGrant.new(valid_grant_claims.merge("surface" => "bad"))
      end

      assert_contract_error(/operation is invalid/) do
        IdentityTelephoneCeremonyGrant.new(valid_grant_claims.merge("operation" => "delete"))
      end
    end
  end

  test "grant rejects forbidden raw otp verifier token claims and unsafe return target" do
    %w(otp verifier_digest session_token refresh_token telephone_number delegated_authorization).each do |claim|
      assert_contract_error(/forbidden claims: #{claim}/) do
        IdentityTelephoneCeremonyGrant.new(valid_grant_claims.merge(claim => "secret"))
      end
    end

    assert_contract_error(/return_to must be relative/) do
      IdentityTelephoneCeremonyGrant.new(valid_grant_claims.merge("return_to" => "https://evil.example/path"))
    end
  end

  test "valid result serializes and deserializes with acme audience binding" do
    travel_to(@now) do
      token = IdentityTelephoneCeremonyResult.issue(valid_result_claims, issuer_id: sign_issuer_id)

      result = IdentityTelephoneCeremonyResult.decode(token, issuer_id: sign_issuer_id)

      assert_equal "telephone_ceremony_result", result["purpose"]
      assert_equal "sms_otp", result["proof_method"]
      assert_equal "registration", result["operation"]
      assert_equal "grant-1", result["grant_jti"]
      assert_equal "result-1", result["result_jti"]
      assert_equal "challenge-1", result["challenge_id"]
      assert_equal IdentityTelephoneCeremonyContract.acme_audience("app"), result["aud"]
      assert_equal JitSecurityJwtKeyring.active_kid(sign_issuer_id), result.kid
    end
  end

  test "result rejects missing required identifiers and expired result" do
    travel_to(@now) do
      assert_contract_error(/missing required claims: grant_jti/) do
        IdentityTelephoneCeremonyResult.new(valid_result_claims.except("grant_jti"))
      end

      assert_contract_error(/missing required claims: result_jti/) do
        IdentityTelephoneCeremonyResult.new(valid_result_claims.merge("result_jti" => ""))
      end

      assert_contract_error(/missing required claims: transaction_id/) do
        IdentityTelephoneCeremonyResult.new(valid_result_claims.merge("transaction_id" => ""))
      end

      assert_contract_error(/expires_at is expired/) do
        IdentityTelephoneCeremonyResult.new(valid_result_claims.merge("expires_at" => 1.second.ago.to_i))
      end
    end
  end

  test "result rejects wrong audience purpose surface operation and proof method" do
    assert_contract_error(/aud is invalid/) do
      IdentityTelephoneCeremonyResult.new(valid_result_claims.merge("aud" => "https://evil.example"))
    end

    assert_contract_error(/purpose is invalid/) do
      IdentityTelephoneCeremonyResult.new(valid_result_claims.merge("purpose" => "wrong"))
    end

    assert_contract_error(/surface is invalid/) do
      IdentityTelephoneCeremonyResult.new(valid_result_claims.merge("surface" => "bad"))
    end

    assert_contract_error(/operation is invalid/) do
      IdentityTelephoneCeremonyResult.new(valid_result_claims.merge("operation" => "delete"))
    end

    assert_contract_error(/proof_method is invalid/) do
      IdentityTelephoneCeremonyResult.new(valid_result_claims.merge("proof_method" => "totp"))
    end
  end

  test "result rejects step up freshness and forbidden otp verifier token claims" do
    %w(otp otp_private_key otp_counter otp_digest session_token refresh_token recent_auth sudo
       step_up_freshness).each do |claim|
      assert_contract_error(/forbidden claims: #{claim}/) do
        IdentityTelephoneCeremonyResult.new(valid_result_claims.merge(claim => "secret"))
      end
    end

    assert_contract_error(/unknown claims: return_to/) do
      IdentityTelephoneCeremonyResult.new(valid_result_claims.merge("return_to" => "/settings/telephones"))
    end
  end

  test "signature verification rejects wrong key tampered payload wrong kid and wrong issuer audience" do
    travel_to(@now) do
      token = IdentityTelephoneCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id)

      assert_contract_error(/kid is unknown|token verification failed/) do
        IdentityTelephoneCeremonyGrant.decode(token, issuer_id: "surface:ACME_COM")
      end

      tampered = tamper_payload(token, "actor_ref" => "actor-client-2")
      assert_contract_error(/token verification failed/) do
        IdentityTelephoneCeremonyGrant.decode(tampered, issuer_id: acme_issuer_id)
      end

      wrong_kid = resign_with_header(token, issuer_id: acme_issuer_id, kid: "unknown-kid")
      assert_contract_error(/kid is unknown/) do
        IdentityTelephoneCeremonyGrant.decode(wrong_kid, issuer_id: acme_issuer_id)
      end

      wrong_audience = sign_payload(
        valid_grant_claims.merge("aud" => "https://evil.example"),
        issuer_id: acme_issuer_id,
      )
      assert_contract_error(/token verification failed|aud/) do
        IdentityTelephoneCeremonyGrant.decode(wrong_audience, issuer_id: acme_issuer_id)
      end
    end
  end

  test "decode_unverified_payload rejects a token whose payload is not a JSON object" do
    header = Base64.urlsafe_encode64(%q({"alg":"none"}), padding: false)

    ["[1]", "5", %q("surface")].each do |body|
      token = "#{header}.#{Base64.urlsafe_encode64(body, padding: false)}."

      error =
        assert_raises(IdentityTelephoneCeremony::Error) do
          IdentityTelephoneCeremonyContract.decode_unverified_payload(token)
        end
      assert_includes error.message, "must be a JSON object", "payload #{body}"
    end
  end

  private

  def acme_issuer_id = IdentityTelephoneCeremonyContract.acme_issuer_id("app")

  def sign_issuer_id = IdentityTelephoneCeremonyContract.sign_issuer_id("app")

  def valid_grant_claims
    {
      "typ" => IdentityTelephoneCeremonyGrant::TOKEN_TYPE,
      "iss" => IdentityTelephoneCeremonyContract.acme_issuer("app"),
      "aud" => IdentityTelephoneCeremonyContract.sign_audience("app"),
      "purpose" => IdentityTelephoneCeremonyGrant::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-client-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "jti" => "grant-1",
      "operation" => "registration",
      "telephone_candidate_ref" => "candidate-1",
      "normalized_number_digest" => "digest-1",
      "return_to" => "/settings/telephones",
      "iat" => @now.to_i,
      "exp" => 5.minutes.from_now.to_i,
    }
  end

  def valid_result_claims
    {
      "typ" => IdentityTelephoneCeremonyResult::TOKEN_TYPE,
      "iss" => IdentityTelephoneCeremonyContract.sign_issuer("app"),
      "aud" => IdentityTelephoneCeremonyContract.acme_audience("app"),
      "purpose" => IdentityTelephoneCeremonyResult::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-client-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "operation" => "registration",
      "proof_method" => IdentityTelephoneCeremonyResult::PROOF_METHOD,
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "telephone_candidate_ref" => "candidate-1",
      "normalized_number_digest" => "digest-1",
      "attempt_count" => 1,
      "iat" => @now.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "expires_at" => 5.minutes.from_now.to_i,
    }
  end

  def assert_contract_error(pattern)
    error = assert_raises(IdentityTelephoneCeremony::Error) { yield }
    assert_match pattern, error.message
  end

  def tamper_payload(token, overrides)
    header_segment, payload_segment, signature_segment = token.split(".")
    payload = JSON.parse(Base64.urlsafe_decode64(pad_base64(payload_segment))).merge(overrides)
    encoded_payload = Base64.urlsafe_encode64(payload.to_json, padding: false)
    [header_segment, encoded_payload, signature_segment].join(".")
  end

  def resign_with_header(token, issuer_id:, kid:)
    payload, = JWT.decode(token, nil, false)
    sign_payload(payload, issuer_id: issuer_id, kid: kid)
  end

  def sign_payload(payload, issuer_id:, kid: nil)
    signing_kid = kid || JitSecurityJwtKeyring.active_kid(issuer_id)
    private_key = JitSecurityJwtKeyring.private_key_for_active(issuer_id)
    JWT.encode(payload, private_key, "ES384", { "typ" => payload.fetch("typ"), "kid" => signing_kid })
  end

  def pad_base64(value)
    padding = (4 - (value.length % 4)) % 4
    value + ("=" * padding)
  end
end
