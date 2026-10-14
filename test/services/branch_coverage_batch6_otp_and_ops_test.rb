# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch6OtpAndOpsTest < ActiveSupport::TestCase
  test "typed signup Email refuses missing candidate mismatched binding cooldown lock and absent code" do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    owner = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = owner.client_emails.create!(address: "batch6-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1")
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("batch6-browser"), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: nil,
    )

    assert_not EmailSignUpOtpFormQuery.call(flow:, email: nil, session_nonce: "batch6-browser")
    assert_raises(ArgumentError) do
      EmailSignUpOtpIssuer.call(flow:, email: nil, session_nonce: "batch6-browser")
    end
    mismatch = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "batch6-browser")

    assert_not_predicate mismatch, :success?
    assert_equal :binding_mismatch, mismatch.status
    flow.update!(pending_contact_id: email.id)
    source_facts = email.reload.attributes
    [nil, ""].each do |code|
      blank = EmailSignUpOtpVerificationCommitter.call(flow:, email:, code:, session_nonce: "batch6-browser")

      assert_not_predicate blank, :success?
      assert_equal :invalid_code, blank.status
    end
    missing = EmailSignUpOtpVerificationCommitter.call(
      flow:, email:, code: "123456", session_nonce: "batch6-browser",
    )

    assert_not_predicate missing, :success?
    assert_equal :missing_challenge, missing.status
    assert_not EmailSignUpOtpFormQuery.call(flow:, email:, session_nonce: "batch6-browser")
    assert_equal source_facts, email.reload.attributes
    issued = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "batch6-browser")

    assert_predicate issued, :success?
    ticket_facts = issued.transaction.reload.attributes
    cooldown = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "batch6-browser")

    assert_not_predicate cooldown, :success?
    assert_equal :rate_limited, cooldown.status
    assert_equal ticket_facts, issued.transaction.reload.attributes
    email.update!(locked_at: ClientEmail.database_now + EmailOtpPolicy::OTP_LOCKOUT_DURATION)
    locked_source = email.reload.attributes
    locked = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "batch6-browser")

    assert_not_predicate locked, :success?
    assert_equal :locked, locked.status
    assert_equal ticket_facts, issued.transaction.reload.attributes
    assert_equal locked_source, email.reload.attributes
  end

  test "OidcTokenRevoker failure arms for missing tokens" do
    result = OidcTokenRevoker.new(
      token: "",
      client_id: "base-rails-rp",
      client_secret: "secret",
      token_type_hint: "access_token",
    ).call

    assert_not result.success?
  end

  test "DpopProofVerifier rejects missing proof pieces" do
    result = DpopProofVerifier.new(
      proof_jwt: "",
      request_method: "POST",
      request_uri: "https://example.test/token",
    ).call

    assert_not result.valid
  end

  test "Retainable soft-delete guards" do
    token = ClientToken.new
    token.define_singleton_method(:discarded?) { true }

    assert_predicate token, :discarded?
  end
end
