# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityStepUpCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
    @client = clients(:one)
    @token = ClientToken.create!(
      user: @client,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
  end

  teardown do
    travel_back
  end

  test "valid explicit grant and result serialize and verify" do
    travel_to @now do
      grant_token = IdentityStepUpCeremonyGrant.issue(
        valid_grant_claims,
        issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id("app"),
        now: @now,
      )
      grant = IdentityStepUpCeremonyGrant.decode(
        grant_token,
        issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id("app"),
        now: @now,
      )

      assert_equal "step_up_ceremony", grant["purpose"]
      assert_equal "settings_email", grant["required_scope"]
      assert_predicate grant, :step_up_required?
      assert_not grant.user_verification_required?
      assert_equal "step_up:app", grant["audience"]

      result_token = IdentityStepUpCeremonyResult.issue(
        valid_result_claims,
        issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
        now: @now,
      )
      result = IdentityStepUpCeremonyResult.decode(
        result_token,
        issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
        now: @now,
      )

      assert_equal "step_up_ceremony_result", result["purpose"]
      assert_equal "totp", result["method"]
      assert_not result["user_verified"]
      assert_not result["phishing_resistant"]
      assert_equal "credential-public-id", result["credential_ref"]
    end
  end

  test "wire values require explicit false evidence and requirement claims" do
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyGrant.new(valid_grant_claims.except("user_verification_required"), now: @now)
    end

    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyResult.new(valid_result_claims.except("user_verified"), now: @now)
    end

    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyResult.new(valid_result_claims.except("phishing_resistant"), now: @now)
    end
  end

  test "result rejects forbidden freshness and secret claims" do
    %w(otp otp_digest session_token refresh_token recent_auth sudo step_up_freshness totp_secret).each do |claim|
      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyResult.new(valid_result_claims.merge(claim => "secret"), now: @now)
        end
      assert_includes error.message, "forbidden claims"
    end
  end

  test "explicit legacy AAL demand is refused at the signed grant boundary" do
    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyGrant.new(valid_grant_claims.merge("required_aal" => "aal2"), now: @now)
      end
    assert_includes error.message, "legacy AAL requirements are unsupported"
  end

  test "telephone otp is not an allowed step-up method" do
    assert_not_includes IdentityStepUpCeremonyContract::METHODS, "telephone_otp"

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyResult.new(valid_result_claims.merge("method" => "telephone_otp"), now: @now)
      end

    assert_includes error.message, "method is invalid"
  end

  test "freshness revoker clears the complete explicit authority tuple" do
    @token.update!(
      last_step_up_at: @now,
      last_step_up_scope: "settings_email",
      last_step_up_aal: "aal2",
      last_step_up_method: "totp",
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false,
      last_step_up_credential_ref: "credential-public-id",
      last_step_up_full_reauthentication: false,
      last_step_up_resource_ref: "resource-public-id",
      last_step_up_tenant_ref: "tenant-public-id",
    )

    IdentityStepUpCeremonyFreshnessRevoker.call!(@token)

    @token.reload

    assert_nil @token.last_step_up_at
    assert_nil @token.last_step_up_scope
    assert_nil @token.last_step_up_method
    assert_nil @token.last_step_up_purpose
    assert_nil @token.last_step_up_audience
    assert_nil @token.last_step_up_session_public_id
    assert_not @token.last_step_up_phishing_resistant
    assert_nil @token.last_step_up_user_verified
    assert_nil @token.last_step_up_credential_ref
    assert_nil @token.last_step_up_full_reauthentication
    assert_nil @token.last_step_up_resource_ref
    assert_nil @token.last_step_up_tenant_ref
  end

  test "fetch_surface_value rejects invalid surfaces" do
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyContract.sign_issuer("bad")
    end
  end

  test "validate_timestamp rejects non-integer iat" do
    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyContract.validate_timestamp!({ "iat" => "not-a-number" }, "iat")
      end
    assert_includes error.message, "iat must be an integer timestamp"
  end

  test "validate_future_timestamp rejects non-integer exp" do
    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyContract.validate_future_timestamp!({ "exp" => "bad" }, "exp", now: @now)
      end
    assert_includes error.message, "exp must be an integer timestamp"
  end

  test "decode_unverified_payload rejects invalid tokens" do
    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyContract.decode_unverified_payload("not.a.jwt")
      end
    assert_includes error.message, "token is invalid"
  end

  test "signature verification rejects wrong key and payload tampering" do
    travel_to @now do
      token = IdentityStepUpCeremonyGrant.issue(
        valid_grant_claims,
        issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id("app"),
        now: @now,
      )

      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyGrant.decode(token, issuer_id: "surface:ACME_COM", now: @now)
        end
      assert_includes error.message, "kid is unknown"

      tampered_payload = valid_grant_claims.merge("actor_ref" => "attacker")
      tampered = token.split(".").tap do |parts|
        parts[1] = Base64.urlsafe_encode64(tampered_payload.to_json, padding: false)
      end.join(".")
      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyGrant.decode(
            tampered, issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id("app"),
                      now: @now,
          )
        end
      assert_includes error.message, "token verification failed"
    end
  end

  test "decode_unverified_payload rejects a token whose payload is not a JSON object" do
    header = Base64.urlsafe_encode64(%q({"alg":"none"}), padding: false)

    ["[1]", "5", %q("surface")].each do |body|
      token = "#{header}.#{Base64.urlsafe_encode64(body, padding: false)}."

      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyContract.decode_unverified_payload(token)
        end
      assert_includes error.message, "must be a JSON object", "payload #{body}"
    end
  end

  private

  def valid_grant_claims
    {
      "typ" => IdentityStepUpCeremonyGrant::TOKEN_TYPE,
      "iss" => IdentityStepUpCeremonyContract.acme_issuer("app"),
      "aud" => IdentityStepUpCeremonyContract.sign_audience("app"),
      "purpose" => IdentityStepUpCeremonyGrant::PURPOSE,
      "surface" => "app",
      "actor_ref" => @client.public_id,
      "session_ref" => @token.public_id,
      "transaction_id" => "step-up-txn",
      "jti" => "step-up-grant",
      "required_scope" => "settings_email",
      "required_aal" => "none",
      "step_up_required" => true,
      "user_verification_required" => false,
      "full_reauthentication_required" => false,
      "phishing_resistant_required" => false,
      "audience" => "step_up:app",
      "token_binding" => @token.public_id,
      "require_session_binding" => true,
      "allowed_methods" => %w(totp passkey email_otp),
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end

  def valid_result_claims
    {
      "typ" => IdentityStepUpCeremonyResult::TOKEN_TYPE,
      "iss" => IdentityStepUpCeremonyContract.sign_issuer("app"),
      "aud" => IdentityStepUpCeremonyContract.acme_audience("app"),
      "purpose" => IdentityStepUpCeremonyResult::PURPOSE,
      "surface" => "app",
      "actor_ref" => @client.public_id,
      "session_ref" => @token.public_id,
      "transaction_id" => "step-up-txn",
      "grant_jti" => "step-up-grant",
      "result_jti" => SecureRandom.uuid,
      "scope" => "settings_email",
      "aal" => "aal1",
      "method" => "totp",
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "phishing_resistant" => false,
      "user_verified" => false,
      "credential_ref" => "credential-public-id",
      "full_reauthentication" => false,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end
end
