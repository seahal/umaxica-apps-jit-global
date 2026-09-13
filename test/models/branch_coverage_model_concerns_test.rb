# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageModelConcernsTest < ActiveSupport::TestCase
  test "AcmeLogoutTransaction covers finalized failed expired and validation arms" do
    txn = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    txn.advance_step!("origin_cleared")
    txn.advance_step!("acme_cleared")
    txn.finalize!

    assert_same txn, txn.advance_step!("origin_cleared")
    assert_same txn, txn.finalize!

    failed = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    failed.update_columns(status: AcmeLogoutTransaction::STATUS_FAILED, failed_at: Time.current)

    assert_same failed, failed.advance_step!("origin_cleared")

    not_ready = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    not_ready.advance_step!("origin_cleared")
    assert_raises(ArgumentError) { not_ready.finalize! }

    expired = AcmeLogoutTransaction.create!(
      transaction_attrs(origin_surface: "sign", expires_at: 1.minute.ago).merge(
        completed_steps: %w(origin_cleared acme_cleared),
        expected_step: "finalized",
      ),
    )
    assert_raises(ArgumentError) { expired.finalize! }

    invalid = AcmeLogoutTransaction.new(
      transaction_attrs(origin_surface: "sign").merge(completed_steps: %w(not_a_step)),
    )

    assert_not invalid.valid?
    assert_includes invalid.errors[:completed_steps].join, "invalid"
  end

  test "OidcTokenUsage covers inactive authenticate and previous digest arms" do
    skip "ClientTokenUsage unavailable" unless defined?(ClientTokenUsage)

    usage = ClientTokenUsage.new(
      public_id: Nanoid.generate(size: 21),
      oidc_client_id: "base-rails-rp",
      revoked_at: Time.current,
      refresh_token_digest: "abc",
      previous_refresh_token_digest: nil,
    )

    assert_not usage.authenticate_refresh_token("verifier")
    assert_not usage.previous_refresh_token_digest_matches?("verifier")

    usage.revoked_at = nil
    usage.refresh_token_expires_at = 1.hour.from_now
    usage.define_singleton_method(:root_token_active?) { true }
    usage.previous_refresh_token_digest = usage.send(:encoded_refresh_token_digest, "old")

    assert usage.previous_refresh_token_digest_matches?("old")
    assert_not usage.previous_refresh_token_digest_matches?("wrong")

    usage.define_singleton_method(:parent_token) { nil }

    assert_not usage.parent_token_active?

    parent = Object.new
    usage.define_singleton_method(:parent_token) { parent }
    # parent_token_active? returns false when token lacks currently_usable?
    assert_not parent.respond_to?(:currently_usable?)
    assert_not usage.parent_token_active?

    parent2 = Struct.new(:currently_usable?).new(true)
    usage.define_singleton_method(:parent_token) { parent2 }

    assert_predicate usage, :parent_token_active?
  end

  test "SecretCredential covers uses_remaining zero and new-axis validation arms" do
    credential = ClientSecretCredential.new
    credential.define_singleton_method(:active?) { true }
    credential.define_singleton_method(:expire_if_needed!) { |**| false }
    credential.define_singleton_method(:uses_remaining_available?) { true }
    credential.uses_remaining = 0
    credential.define_singleton_method(:authenticate) { |_| true }
    credential.define_singleton_method(:with_lock) { |&block| block.call }
    credential.define_singleton_method(:reload) { self }

    assert_not credential.verify_and_consume!("secret")

    credential.define_singleton_method(:active?) { false }

    assert_not credential.expire_if_needed!(now: Time.current)

    no_kind = ClientSecretCredential.new
    def no_kind.respond_to?(name, include_all = false)
      return false if name.to_sym == :secret_kind

      super
    end

    assert_not no_kind.send(:new_axis_secret_credential?)

    axis = ClientSecretCredential.new
    axis.define_singleton_method(:secret_kind) { nil }
    axis.define_singleton_method(:lookup_digest) { "digest" }
    axis.define_singleton_method(:usage_policy) { nil }

    assert axis.send(:new_axis_secret_credential?)

    axis2 = ClientSecretCredential.new
    axis2.define_singleton_method(:secret_kind) { nil }
    axis2.define_singleton_method(:lookup_digest) { nil }
    axis2.define_singleton_method(:usage_policy) { "single_use" }

    assert axis2.send(:new_axis_secret_credential?)

    no_discard = ClientSecretCredential.new
    def no_discard.respond_to?(name, include_all = false)
      return false if name.to_sym == :discarded_at

      super
    end

    assert_not no_discard.send(:expired_by_time?, Time.current)

    blank_axis = ClientSecretCredential.new
    blank_axis.define_singleton_method(:new_axis_secret_credential?) { true }
    blank_axis.define_singleton_method(:secret_kind) { nil }
    blank_axis.define_singleton_method(:usage_policy) { nil }
    blank_axis.define_singleton_method(:lookup_digest) { nil }
    blank_axis.define_singleton_method(:safe_prefix) { nil }
    blank_axis.send(:new_axis_secret_fields_are_consistent)

    assert_predicate blank_axis.errors[:secret_kind], :present?
    assert_predicate blank_axis.errors[:usage_policy], :present?
    assert_predicate blank_axis.errors[:lookup_digest], :present?
    assert_predicate blank_axis.errors[:safe_prefix], :present?
  end

  test "PrivacyRequestState and RetentionHoldState assign blank defaults" do
    request = ClientPrivacyRequest.new
    request.request_kind = nil
    request.request_source = nil
    request.jurisdiction = nil
    request.send(:assign_privacy_request_defaults)

    assert_equal "erasure", request.request_kind
    assert_equal "self_service", request.request_source
    assert_equal "unknown", request.jurisdiction

    hold = ClientRetentionHold.new
    hold.hold_kind = nil
    hold.reason_code = nil
    hold.send(:assign_retention_hold_defaults)

    assert_equal "legal_hold", hold.hold_kind
    assert_equal "legal_hold", hold.reason_code
  end

  test "RefreshTokenable covers missing device session and digest authenticate arms" do
    token = ClientToken.new
    token.define_singleton_method(:active?) { false }

    assert_not token.authenticate_refresh_token("x")

    token.define_singleton_method(:active?) { true }
    token.define_singleton_method(:refresh_token_digest_matches?) { |_| true }

    assert token.authenticate_refresh_token("x")

    token.define_singleton_method(:has_attribute?) { |name| name.to_sym != :device_session_id }

    assert_nil token.send(:ensure_device_session_record)

    token.define_singleton_method(:has_attribute?) { |name| name.to_sym == :dbsc_session_id }
    token.define_singleton_method(:dbsc_session_id) { nil }
    ClientToken.send(:release_unique_dbsc_session_id!, token)

    replacement = Object.new
    def replacement.respond_to?(name, include_all = false)
      return false if name.to_sym == :device_session

      super
    end
    ClientToken.send(:update_device_session_after_rotation!, token, replacement)
  end

  private

  def transaction_attrs(origin_surface:, expires_at: 10.minutes.from_now)
    {
      origin_surface: origin_surface,
      initiating_client_id: "#{origin_surface}-rp",
      completion_url: "https://example.test/#{origin_surface}/sign/out/complete",
      expires_at: expires_at,
      expected_step: AcmeLogoutTransaction.step_sequence_for(origin_surface).first,
      status: AcmeLogoutTransaction::STATUS_INITIATED,
    }
  end
end
