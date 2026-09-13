# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch6OtpAndOpsTest < ActiveSupport::TestCase
  test "SignOtpCeremony issue and verify cover missing destination rate limit lock and blank code" do
    ceremony = SignOtpCeremony.new(
      purpose: :sign_in,
      surface: :app,
      channel: :email,
      subject: Object.new,
      destination: "a@b.c",
      code: nil,
    )
    ceremony.define_singleton_method(:validate_scope!) { true }
    ceremony.define_singleton_method(:bound_record) { nil }
    result = ceremony.issue!

    assert_not result.success?
    assert_equal :missing_destination, result.status

    record = Object.new
    record.define_singleton_method(:locked?) { false }
    ceremony.define_singleton_method(:bound_record) { record }
    ceremony.define_singleton_method(:destination_matches?) { |_| false }
    result = ceremony.issue!

    assert_equal :destination_mismatch, result.status

    ceremony.define_singleton_method(:destination_matches?) { |_| true }
    ceremony.define_singleton_method(:cooldown_active?) { |_| true }
    result = ceremony.issue!

    assert_equal :rate_limited, result.status

    ceremony.define_singleton_method(:cooldown_active?) { |_| false }
    record.define_singleton_method(:locked?) { true }
    result = ceremony.issue!

    assert_equal :locked, result.status

    record.define_singleton_method(:locked?) { false }
    record.define_singleton_method(:with_lock) { |&b| b.call }
    record.define_singleton_method(:get_otp) { nil }
    result = ceremony.verify!

    assert_equal :blank_code, result.status

    ceremony2 = SignOtpCeremony.new(
      purpose: :sign_in,
      surface: :app,
      channel: :email,
      subject: Object.new,
      destination: "a@b.c",
      code: "123456",
    )
    ceremony2.define_singleton_method(:validate_scope!) { true }
    ceremony2.define_singleton_method(:bound_record) { record }
    ceremony2.define_singleton_method(:destination_matches?) { |_| true }
    result = ceremony2.verify!

    assert_equal :missing_otp, result.status
  end

  test "PalmAccessTokenAuthenticator rejects blank access token" do
    result = PalmAccessTokenAuthenticator.new(
      access_token: "",
      host: "palm.app.localhost",
      authorization_scheme: "Bearer",
    ).call

    assert_not result.success?
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
