# frozen_string_literal: true

require "test_helper"

class ClientSecretIssuanceUniquenessTest < ActiveSupport::TestCase
  test "issuance attempts keep operation scope and raw uniqueness" do
    operation = SecureRandom.uuid
    attributes = { client: clients(:one),
                   origin_operation_id: operation,
                   origin: "manual",
                   attempt_number: 1,
                   browser_session_ref: "issuance-uniqueness",
                   planned_count: 0, }
    first = ClientSecretIssuance.create!(attributes)
    later = ClientSecretIssuance.create!(attributes.merge(attempt_number: 2))
    other = ClientSecretIssuance.create!(attributes.merge(origin_operation_id: SecureRandom.uuid))

    assert_equal :omitted, first.state(at: Client.database_now)
    assert_equal 2, later.attempt_number
    assert_equal 1, other.attempt_number
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientSecretIssuance.transaction(requires_new: true) do
        ClientSecretIssuance.new(attributes).save!(validate: false)
      end
    end
    first.save!

    assert_equal operation, first.reload.origin_operation_id
  end

  test "issuance preflight refuses the same operation and attempt across owners" do
    attributes = { client: clients(:one),
                   origin_operation_id: SecureRandom.uuid,
                   origin: "manual",
                   attempt_number: 1,
                   browser_session_ref: "issuance-uniqueness",
                   planned_count: 0, }
    ClientSecretIssuance.create!(attributes)
    duplicate = ClientSecretIssuance.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:attempt_number, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    other_owner = ClientSecretIssuance.new(attributes.merge(client: clients(:two)))

    assert_not other_owner.valid?
    assert other_owner.errors.of_kind?(:attempt_number, :taken)
  end
end
