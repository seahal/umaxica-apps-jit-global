# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Source binding and authorization belong to the finalizer; this model contract only writes its Ticket receipt.
# Boolean snapshots keep original references out of assertion failure output.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class ContactRegistrationReceiptTest < ActiveSupport::TestCase
  [
    [ClientEmailCeremonyTransaction, "app", IdentityEmailCeremonyContract::Error],
    [ClientTelephoneCeremonyTransaction, "app", IdentityTelephoneCeremony::Error],
    [VisitorEmailCeremonyTransaction, "com", IdentityEmailCeremonyContract::Error],
    [VisitorTelephoneCeremonyTransaction, "com", IdentityTelephoneCeremony::Error],
  ].each do |model, surface, error_class|
    test "#{model} registration receipt uses its own DB clock and retains a canonical terminal receipt" do
      transaction = model.create_transaction!(
        surface:, actor_ref: SecureRandom.urlsafe_base64(12), session_ref: SecureRandom.urlsafe_base64(12),
        operation: "registration",
      )
      original = transaction.reload.attributes
      decision_time = model.database_now + 1.second

      model.stub(:database_now, decision_time) do
        assert_same transaction, transaction.consume_registration_result!
      end
      transaction.reload

      assert_predicate transaction, :consumed?
      assert_equal decision_time, transaction.consumed_at
      assert transaction.result_jti.is_a?(String) &&
        transaction.result_jti.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/),
             "Receipt must own a canonical UUIDv4 result identifier"
      changed_fields = %w(status consumed_at result_jti lock_version updated_at)

      assert original.except(*changed_fields) == transaction.attributes.except(*changed_fields),
             "Receipt must retain every original Ticket binding and deadline"
      terminal = transaction.attributes

      assert_raises(error_class) { transaction.consume_registration_result! }
      assert terminal == transaction.reload.attributes, "Terminal replay must not replace the original receipt"
    end

    [-1, 0, 1].each do |offset|
      test "#{model} registration receipt expiry at #{offset} microseconds preserves unavailable Ticket facts" do
        transaction = model.create_transaction!(
          surface:, actor_ref: SecureRandom.urlsafe_base64(12), session_ref: SecureRandom.urlsafe_base64(12),
          operation: "registration",
        )
        original = transaction.reload.attributes
        # PostgreSQL timestamptz(6) represents both nearest neighbors of the strict expiration boundary.
        decision_time = transaction.expires_at + Rational(offset, 1_000_000)
        model.stub(:database_now, decision_time) do
          if offset.negative?
            assert_same transaction, transaction.consume_registration_result!
          else
            assert_raises(error_class) { transaction.consume_registration_result! }
          end
        end
        transaction.reload
        if offset.negative?
          assert_predicate transaction, :consumed?
          assert_equal decision_time, transaction.consumed_at
          assert_not_nil transaction.result_jti
          assert original.except("status", "consumed_at", "result_jti", "lock_version", "updated_at") ==
            transaction.attributes.except("status", "consumed_at", "result_jti", "lock_version", "updated_at"),
                 "A boundary success must retain all original Ticket authority"
        else
          assert original == transaction.attributes, "Expiry refusal must not write a receipt or alter Ticket facts"
          assert_nil transaction.consumed_at
          assert_nil transaction.result_jti
        end
      end
    end

    test "#{model} replacement operation cannot be consumed by the registration receipt writer" do
      transaction = model.create_transaction!(
        surface:, actor_ref: SecureRandom.urlsafe_base64(12), session_ref: SecureRandom.urlsafe_base64(12),
        operation: "replacement",
      )
      original = transaction.reload.attributes

      assert_raises(error_class) { transaction.consume_registration_result! }
      assert original == transaction.reload.attributes, "Wrong-operation refusal must preserve every Ticket fact"
    end

    test "#{model} registration receipt rejects caller time result identifier and nil argument sentinels" do
      transaction = model.create_transaction!(
        surface:, actor_ref: SecureRandom.urlsafe_base64(12), session_ref: SecureRandom.urlsafe_base64(12),
        operation: "registration",
      )
      original = transaction.reload.attributes

      assert_raises(ArgumentError) { transaction.consume_registration_result!(nil) }
      assert_raises(ArgumentError) { transaction.consume_registration_result!(now: nil) }
      assert_raises(ArgumentError) { transaction.consume_registration_result!(now: model.database_now) }
      assert_raises(ArgumentError) { transaction.consume_registration_result!(consumed_at: model.database_now) }
      assert_raises(ArgumentError) { transaction.consume_registration_result!(result_jti: SecureRandom.uuid) }
      assert original == transaction.reload.attributes, "Caller-supplied receipt facts must not change the Ticket"
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
