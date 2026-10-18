# frozen_string_literal: true

require "test_helper"

class OwnershipTransferRequestValidationTest < ActiveSupport::TestCase
  {
    ClientPersonaOwnershipTransferRequest => %i(source_client_id destination_client_id),
    EnterpriseOwnershipTransferRequest => %i(source_client_id destination_client_id),
    IndividualOwnershipTransferRequest => %i(source_visitor_id destination_visitor_id),
    CompanyOwnershipTransferRequest => %i(source_visitor_id destination_visitor_id),
    AgentOwnershipTransferRequest => %i(source_operator_id destination_operator_id),
    BureauOwnershipTransferRequest => %i(source_operator_id destination_operator_id),
  }.each do |model_class, (source_attr, destination_attr)|
    test "#{model_class.name} rejects identical parties and inverted expiry" do
      record = model_class.new(
        :status => model_class::PENDING,
        :expected_ownership_revision => 0,
        :requested_at => Time.current,
        :expires_at => 1.hour.ago,
        source_attr => 1,
        destination_attr => 1,
      )

      assert_not record.valid?
      assert_includes record.errors[destination_attr], "must differ from #{source_attr}"
      assert_includes record.errors[:expires_at], "must be after requested_at"
    end

    test "#{model_class.name} accepts differing parties with a future expiry" do
      record = model_class.new(
        :status => model_class::PENDING,
        :expected_ownership_revision => 0,
        :requested_at => Time.current,
        :expires_at => 1.hour.from_now,
        source_attr => 1,
        destination_attr => 2,
      )
      record.validate

      assert_empty record.errors[destination_attr]
      assert_empty record.errors[:expires_at]
    end

    test "#{model_class.name} skips party and expiry checks when attributes are blank" do
      record = model_class.new(
        status: model_class::PENDING,
        expected_ownership_revision: 0,
        requested_at: nil,
        expires_at: nil,
      )
      record.validate

      assert_empty record.errors[destination_attr]
      assert_empty record.errors[:expires_at]
    end
  end
end
