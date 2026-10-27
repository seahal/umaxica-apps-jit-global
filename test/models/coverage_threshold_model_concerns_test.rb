# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdModelConcernsTest < ActiveSupport::TestCase
  FakeAttributes =
    Struct.new(:attributes) do
      def has_attribute?(name)
        attributes.include?(name)
      end
    end

  test "refresh token primitives distinguish expiry, revocation, and digest states" do
    token = ClientToken.new
    token.discard_at = nil

    # A missing refresh-token expiry is invalid authentication state, not an
    # unbounded usable lifetime.
    assert_predicate token, :expired_refresh?
    token.discard_at = Float::INFINITY

    assert_predicate token, :expired_refresh?
    token.discard_at = 1.hour.from_now

    assert_not_predicate token, :expired_refresh?
    token.discard_at = 1.hour.ago

    assert_predicate token, :expired_refresh?
    token.define_singleton_method(:revoked?) { true }

    assert_not_predicate token, :active?
    token.define_singleton_method(:revoked?) { false }
    token.refresh_token = "verifier"

    assert token.refresh_token_digest_matches?("verifier")
    assert_not token.refresh_token_digest_matches?("wrong")
    assert_not token.refresh_token_digest_matches?(nil)
    token.refresh_token = nil

    assert_nil token.refresh_token_digest
    assert_equal({ status: :invalid, token: nil }, ClientToken.rotate_refresh!(presented_refresh_digest: nil))
  end

  test "token status management distinguishes active restricted revoked and expired states" do
    token = ClientToken.new(user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.hour.from_now)

    assert_predicate token, :active_status?
    assert_not_predicate token, :restricted?
    assert_not_predicate token, :revoked?
    assert_not_predicate token, :expired?
    token.user_token_status_id = ClientTokenStatus::RESTRICTED

    assert_predicate token, :restricted?
    token.user_token_status_id = ClientTokenStatus::REVOKED

    assert_predicate token, :revoked?
    assert_predicate token, :expired?
    token.user_token_status_id = ClientTokenStatus::EXPIRED

    assert_predicate token, :expired?
    token.user_token_status_id = ClientTokenStatus::ACTIVE
    token.discard_at = 1.hour.ago

    assert_predicate token, :scheduled_revocation_due?
    assert_not_predicate token, :currently_usable?
    assert_equal ClientTokenStatus, ClientToken.token_status_model
    assert_equal :user_token_status_id, ClientToken.token_status_foreign_key
    assert_equal :discard_at, ClientToken.expiry_column
  end
end
