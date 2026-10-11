# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

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

  test "valid grant and result serialize and verify" do
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

  test "freshness committer writes token freshness and rejects replay mismatches" do
    travel_to @now do
      result_token = IdentityStepUpCeremonyResult.issue(
        valid_result_claims,
        issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
        now: @now,
      )

      IdentityStepUpCeremonyFreshnessCommitter.call!(
        result_token: result_token,
        token: @token,
        expected_scope: "settings_email",
        expected_aal: "aal2",
        expected_method: "totp",
        audience: "step_up:app",
        surface: "app",
        now: @now,
      )

      @token.reload

      assert_equal @now.to_i, @token.last_step_up_at.to_i
      assert_equal "settings_email", @token.last_step_up_scope
      assert_equal "aal2", @token.last_step_up_aal
      assert_equal "totp", @token.last_step_up_method
      assert_equal "step_up", @token.last_step_up_purpose
      assert_equal "step_up:app", @token.last_step_up_audience

      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyFreshnessCommitter.call!(
          result_token: result_token,
          token: @token,
          expected_scope: "settings_telephone",
          expected_aal: "aal2",
          expected_method: "totp",
          audience: "step_up:app",
          surface: "app",
          now: @now,
        )
      end
    end
  end

  test "freshness committer rejects a blank token and mismatched actor session method or aal" do
    travel_to @now do
      result_token = IdentityStepUpCeremonyResult.issue(
        valid_result_claims,
        issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
        now: @now,
      )

      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            result_token: result_token,
            token: nil,
            expected_scope: "settings_email",
            expected_aal: "aal2",
            expected_method: "totp",
            audience: "step_up:app",
            surface: "app",
            now: @now,
          )
        end
      assert_includes error.message, "token is required"

      other_client = Client.create!(status_id: ClientStatus::NOTHING)
      other = ClientToken.create!(
        user: other_client,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
      )
      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            result_token: result_token,
            token: other,
            expected_scope: "settings_email",
            expected_aal: "aal2",
            expected_method: "totp",
            audience: "step_up:app",
            surface: "app",
            now: @now,
          )
        end
      assert_includes error.message, "result actor does not match current actor"

      mismatched_session = ClientToken.create!(
        user: @client,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
      )
      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            result_token: result_token,
            token: mismatched_session,
            expected_scope: "settings_email",
            expected_aal: "aal2",
            expected_method: "totp",
            audience: "step_up:app",
            surface: "app",
            now: @now,
          )
        end
      assert_includes error.message, "result session does not match current session"

      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            result_token: result_token,
            token: @token,
            expected_scope: "settings_email",
            expected_aal: "aal2",
            expected_method: "passkey",
            audience: "step_up:app",
            surface: "app",
            now: @now,
          )
        end
      assert_includes error.message, "result method does not match ceremony"
    end
  end

  test "freshness committer rejects an insufficient AAL and records only attributes the token has" do
    travel_to @now do
      low_aal = IdentityStepUpCeremonyResult.issue(
        valid_result_claims.merge("aal" => "aal1", "result_jti" => SecureRandom.uuid),
        issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
        now: @now,
      )
      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            result_token: low_aal,
            token: @token,
            expected_scope: "settings_email",
            expected_aal: "aal2",
            expected_method: "totp",
            audience: "step_up:app",
            surface: "app",
            now: @now,
          )
        end
      assert_includes error.message, "result AAL is insufficient"

      result_token = IdentityStepUpCeremonyResult.issue(
        valid_result_claims.merge(
          "result_jti" => SecureRandom.uuid, "actor_ref" => "visitor-1",
          "session_ref" => "visitor-session",
        ),
        issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
        now: @now,
      )
      visitor_token = VisitorOnlyStepUpToken.new(
        public_id: "visitor-session", visitor: Struct.new(:public_id).new("visitor-1"),
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        result_token: result_token,
        token: visitor_token,
        expected_scope: "settings_email",
        expected_aal: "aal2",
        expected_method: "totp",
        audience: "step_up:app",
        surface: "app",
        now: @now,
      )

      assert_equal "settings_email", visitor_token.updated.fetch(:last_step_up_scope)
      assert_equal @now.to_i, visitor_token.updated.fetch(:last_step_up_at).to_i

      staff_token = StaffOnlyStepUpToken.new(
        public_id: "visitor-session", staff: Struct.new(:public_id).new("visitor-1"),
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        result_token: result_token,
        token: staff_token,
        expected_scope: "settings_email",
        expected_aal: "aal2",
        expected_method: "totp",
        audience: "step_up:app",
        surface: "app",
        now: @now,
      )

      assert_equal "visitor-1", staff_token.staff.public_id
    end
  end

  test "freshness revoker clears only the freshness columns the token actually has" do
    bare = BareStepUpToken.new(public_id: "sess")
    IdentityStepUpCeremonyFreshnessRevoker.call!(bare)

    assert_equal({ last_step_up_at: nil, last_step_up_scope: nil }, bare.updated)
  end

  class BareStepUpToken
    attr_reader :public_id, :updated

    def initialize(public_id:)
      @public_id = public_id
    end

    def update!(attrs)
      @updated = attrs
    end

    def has_attribute?(_name) = false
  end

  class VisitorOnlyStepUpToken < BareStepUpToken
    attr_reader :visitor

    def initialize(public_id:, visitor:)
      super(public_id: public_id)
      @visitor = visitor
    end
  end

  class StaffOnlyStepUpToken < BareStepUpToken
    attr_reader :staff

    def initialize(public_id:, staff:)
      super(public_id: public_id)
      @staff = staff
    end
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

  test "signature verification rejects wrong key and tampering" do
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

  # SMS is not an accepted step-up proof, so telephone_otp must not survive as
  # an allowed method value.
  test "telephone otp is not an allowed step-up method" do
    assert_not_includes IdentityStepUpCeremonyContract::METHODS, "telephone_otp"

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyResult.new(valid_result_claims.merge("method" => "telephone_otp"), now: @now)
      end

    assert_includes error.message, "method is invalid"
  end

  test "freshness committer rejects a result whose surface differs from the caller surface" do
    travel_to @now do
      result_token = IdentityStepUpCeremonyResult.issue(
        valid_result_claims,
        issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
        now: @now,
      )

      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            result_token: result_token,
            token: @token,
            expected_scope: "settings_email",
            expected_aal: "aal2",
            expected_method: "totp",
            audience: "step_up:app",
            surface: "org",
            now: @now,
          )
        end

      assert_includes error.message, "kid is unknown"
      assert_nil @token.reload.last_step_up_at
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
      "required_aal" => "aal2",
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
      "aal" => "aal2",
      "method" => "totp",
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end
end
