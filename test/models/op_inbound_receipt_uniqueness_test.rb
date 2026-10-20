# frozen_string_literal: true

require "test_helper"

class OpInboundReceiptUniquenessTest < ActiveSupport::TestCase
  RECEIPTS = [OpAppInboundEventReceipt, OpComInboundEventReceipt, OpOrgInboundEventReceipt].freeze

  RECEIPTS.each do |receipt_class|
    test "#{receipt_class.name} retains sender partitions and raw dedup enforcement" do
      attributes = { event_id: SecureRandom.uuid,
                     issuer: "https://issuer.example.test",
                     realm: receipt_class::REALM,
                     client_id: "first-client",
                     event_type: "identity_authentication_stop",
                     committed_at: Time.current, }
      first = receipt_class.create!(attributes)

      assert_predicate receipt_class.create!(attributes.merge(client_id: "other-client")), :persisted?
      assert_predicate receipt_class.create!(attributes.merge(issuer: "https://other.example.test")), :persisted?
      assert_predicate receipt_class.create!(attributes.merge(event_id: SecureRandom.uuid)), :persisted?
      assert_raises(ActiveRecord::RecordNotUnique) do
        receipt_class.transaction(requires_new: true) { receipt_class.new(attributes).save!(validate: false) }
      end
      first.save!

      assert_equal attributes.fetch(:event_id), first.reload.event_id
    end

    test "#{receipt_class.name} excludes event type from its sender and event key" do
      attributes = { event_id: SecureRandom.uuid,
                     issuer: "https://issuer.example.test",
                     realm: receipt_class::REALM,
                     client_id: "first-client",
                     event_type: "identity_authentication_stop",
                     committed_at: Time.current, }
      receipt_class.create!(attributes)
      duplicate = receipt_class.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:event_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      other_type = receipt_class.new(attributes.merge(event_type: "other"))

      assert_not other_type.valid?
      assert other_type.errors.of_kind?(:event_id, :taken)
    end
  end
end
