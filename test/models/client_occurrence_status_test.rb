# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_occurrence_statuses
# Database name: occurrence
#
#  id   :bigint           not null, primary key
#  name :string           default(""), not null
#

require "test_helper"

class ClientOccurrenceStatusTest < ActiveSupport::TestCase
  #   test "expires_at default" do
  #     record = ClientOccurrenceStatus.new(id: "EXPIRES_AT_TEST")
  #
  #     assert_expires_at_default(record)
  #   end

  test "can load nothing status from db" do
    nothing = ClientOccurrenceStatus.find(ClientOccurrenceStatus::NOTHING)

    assert_not_nil nothing
    assert_equal 0, nothing.id
  end

  test "constants are defined" do
    assert_equal 0, ClientOccurrenceStatus::NOTHING
    assert_equal 2, ClientOccurrenceStatus::ACTIVE
    assert_equal 3, ClientOccurrenceStatus::INACTIVE
    assert_equal 4, ClientOccurrenceStatus::DELETED
  end

  test "ensure_defaults! creates default records" do
    ClientOccurrenceStatus.ensure_defaults!

    ClientOccurrenceStatus::DEFAULTS.each do |id|
      assert ClientOccurrenceStatus.exists?(id), "missing default client occurrence status #{id}"
    end
  end
end
