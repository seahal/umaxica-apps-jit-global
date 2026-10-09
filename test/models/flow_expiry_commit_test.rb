# frozen_string_literal: true

require "test_helper"

class FlowExpiryCommitTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "standalone sign-in expiry commits before raising in every realm" do
    [ClientSignInFlow, VisitorSignInFlow, OperatorSignInFlow].each do |model|
      flow = nil
      begin
        now = model.database_now
        flow = model.create!(
          nonce_digest: model.digest_nonce(SecureRandom.hex(16)),
          issued_at: now - 2.minutes, expires_at: now - 1.minute,
        )

        assert_not model.lease_connection.transaction_open?
        assert_raises(FlowInvalidTransition) { flow.complete_sign_in! }
        assert_predicate model.find(flow.id), :sign_in_expired?
      ensure
        flow&.destroy!
      end
    end
  end
  test "expiry ownership follows the writer transaction when the caller temporarily selects reading" do
    [ClientSignInFlow, VisitorSignInFlow, OperatorSignInFlow].each do |model|
      flow = nil
      begin
        now = model.database_now
        flow = model.create!(
          nonce_digest: model.digest_nonce(SecureRandom.hex(16)),
          issued_at: now - 2.minutes, expires_at: now - 1.minute,
        )
        outcome =
          model.transaction do
            model.connection_class_for_self.connected_to(role: :reading) { flow.advance_sign_in_to_mfa! }
          end

        assert_predicate outcome, :expired?
        assert_predicate model.find(flow.id), :sign_in_expired?
        assert_raises(FlowInvalidTransition) { outcome.value! }
      ensure
        flow&.destroy!
      end
    end
  end
end
