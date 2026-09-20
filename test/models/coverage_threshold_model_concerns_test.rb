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
    token.discarded_at = nil

    assert_not_predicate token, :expired_refresh?
    token.discarded_at = Float::INFINITY

    assert_not_predicate token, :expired_refresh?
    token.discarded_at = 1.hour.from_now

    assert_not_predicate token, :expired_refresh?
    token.discarded_at = 1.hour.ago

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
    token = ClientToken.new(user_token_status_id: ClientTokenStatus::ACTIVE)

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
    token.discarded_at = 1.hour.ago

    assert_predicate token, :scheduled_revocation_due?
    assert_not_predicate token, :currently_usable?
    assert_equal ClientTokenStatus, ClientToken.token_status_model
    assert_equal :user_token_status_id, ClientToken.token_status_foreign_key
    assert_equal :discarded_at, ClientToken.expiry_column
  end

  test "logout transaction exposes origin sequences and status predicates" do
    transaction = AcmeLogoutTransaction.new(
      origin_surface: "sign", status: "initiated",
      expected_step: "origin_cleared", expires_at: 1.hour.from_now, completed_steps: [],
    )

    assert_equal ["origin_cleared", "acme_cleared"], transaction.step_sequence
    assert_predicate transaction, :initiated?
    assert_not_predicate transaction, :in_progress?
    assert_not_predicate transaction, :finalized?
    assert_not_predicate transaction, :failed?
    assert_not_predicate transaction, :expired?
    assert_not_predicate transaction, :expected_finalization?
    assert_raises(ArgumentError) { AcmeLogoutTransaction.step_sequence_for("unknown") }
    assert_equal ["origin_cleared", "sign_cleared"], AcmeLogoutTransaction.step_sequence_for("base")
    assert_equal %w(origin_cleared acme_cleared sign_cleared), AcmeLogoutTransaction.step_sequence_for("core")
    transaction.status = "failed"

    assert_predicate transaction, :failed?
    transaction.status = "finalized"

    assert_predicate transaction, :finalized?
    assert_predicate AcmeLogoutTransaction.new(expires_at: 1.minute.ago), :expired?
  end
end

class CoverageThresholdModelConcernsTest
  test "logout step advancement covers duplicate invalid and finalization guards" do
    t = AcmeLogoutTransaction.new(
      origin_surface: "sign", status: "in_progress", expected_step: "origin_cleared",
      expires_at: 1.hour.from_now, completed_steps: [],
    )
    t.define_singleton_method(:transaction) { |&block| block.call }
    t.define_singleton_method(:lock!) { true }
    t.define_singleton_method(:update!) { |attrs|
      attrs.each { |k, v|
        public_send("#{k}=", v) if respond_to?("#{k}=")
      }; self
    }

    assert_same t, t.advance_step!("origin_cleared")
    assert_equal "acme_cleared", t.expected_step
    assert_same t, t.advance_step!("origin_cleared")
    assert_raises(ArgumentError) { t.advance_step!("wrong") }
    expired = AcmeLogoutTransaction.new(
      origin_surface: "sign", expected_step: "origin_cleared",
      expires_at: 1.minute.ago, completed_steps: [],
    )
    assert_raises(ArgumentError) { expired.advance_step!("origin_cleared") }
    assert_raises(ArgumentError) { t.finalize! }
    t.define_singleton_method(:update!) { |attrs|
      attrs.each { |k, v|
        public_send("#{k}=", v) if respond_to?("#{k}=")
      }; self
    }
    t.status = "failed"

    assert_same t, t.fail!
  end
end
