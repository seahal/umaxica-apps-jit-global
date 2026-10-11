# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch4SmallFilesTest < ActiveSupport::TestCase
  test "privacy request cancel only when received" do
    request = ClientPrivacyRequest.new
    request.send(:assign_privacy_request_defaults)
    request.define_singleton_method(:update!) { |**attrs|
      attrs.each { |k, v|
        send("#{k}=", v) if respond_to?("#{k}=")
      }; true
    }
    request.cancel_from_recovery!

    assert_equal ClientPrivacyRequest.status_id_for("CANCELLED"), request.status_id

    processing = ClientPrivacyRequest.new
    processing.send(:assign_privacy_request_defaults)
    processing.status_id = ClientPrivacyRequest.status_id_for("PROCESSING")
    processing.cancel_from_recovery!

    assert_equal ClientPrivacyRequest.status_id_for("PROCESSING"), processing.status_id
  end

  test "retention hold defaults fill blanks" do
    hold = ClientRetentionHold.new
    hold.hold_kind = nil
    hold.reason_code = nil
    hold.send(:assign_retention_hold_defaults)

    assert_equal "legal_hold", hold.hold_kind
    assert_equal "legal_hold", hold.reason_code
  end

  test "identity ceremony results reject future verified_at for email" do
    now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    future = now + IdentityEmailCeremonyContract::LEEWAY + 120
    payload = {
      "typ" => IdentityEmailCeremonyResult::TOKEN_TYPE,
      "iss" => IdentityEmailCeremonyContract.sign_issuer("app"),
      "aud" => IdentityEmailCeremonyContract.acme_audience("app"),
      "purpose" => IdentityEmailCeremonyResult::PURPOSE,
      "surface" => "app",
      "actor_ref" => "a",
      "session_ref" => "s",
      "transaction_id" => "t",
      "grant_jti" => "g",
      "result_jti" => "r",
      "operation" => "registration",
      "proof_method" => IdentityEmailCeremonyResult::PROOF_METHOD,
      "email_digest" => "digest",
      "verified_at" => future.to_i,
      "challenge_id" => "c",
      "expires_at" => (now + 5.minutes).to_i,
      "iat" => now.to_i,
      "exp" => (now + 5.minutes).to_i,
    }
    assert_raises(IdentityEmailCeremonyContract::Error) do
      IdentityEmailCeremonyResult.new(payload, now: now)
    end
  end

  test "RedirectsSignedTargetSupport and CommonRedirect remaining edges" do
    klass =
      Class.new(ApplicationController) do
        include CommonRedirect
        include RedirectsSignedTargetSupport

        def request = ActionDispatch::TestRequest.create

        def session = {}

        def redirect_to(*) = nil
      end
    h = klass.new

    assert_nil h.send(:signed_target_internal_path, "http://evil.example/x")
    assert_nil h.send(:signed_target_internal_path, "user:pass@/x")
    h.send(:log_signed_target_rejection, "evt", "reason", payload: nil)
  end

  test "preference refresh transport create_if_missing false" do
    require Rails.root.join("test/controllers/concerns/preference/core_test").to_s
    klass =
      Class.new(PreferenceCoreHarness) do
        include PreferenceRefreshTokenTransport

        def cookies = {}

        def handle_preference_refresh_failed(*) = nil

        def create_new_preference_record! = flunk("should not create")
      end
    h = klass.new
    h.define_singleton_method(:find_preference_by_refresh_token) { |*| nil }
    # Method may need cookie present; stub load path
    h.define_singleton_method(:extract_preference_refresh_token) { [nil, nil] }
    result = h.send(:load_preference_record_from_refresh_token!, create_if_missing: false)

    assert_equal [nil, false], result
  end
end
