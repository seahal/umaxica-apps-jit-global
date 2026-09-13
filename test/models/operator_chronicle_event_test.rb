# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorChronicleEventTest < ActiveSupport::TestCase
  setup do
    @model_class = OperatorChronicleEvent
    @valid_id = OperatorChronicleEvent::LOGGED_IN
    @subject = @model_class.new(id: @valid_id)
  end

  test "accepts integer ids" do
    record = OperatorChronicleEvent.new(id: 9)

    assert_predicate record, :valid?
  end

  test "all constants are defined with correct values" do
    assert_equal 1, OperatorChronicleEvent::LOGIN_SUCCESS
    assert_equal 2, OperatorChronicleEvent::AUTHORIZATION_FAILED
    assert_equal 3, OperatorChronicleEvent::LOGGED_IN
    assert_equal 4, OperatorChronicleEvent::LOGGED_OUT
    assert_equal 5, OperatorChronicleEvent::LOGIN_FAILED
    assert_equal 6, OperatorChronicleEvent::TOKEN_REFRESHED
    assert_equal 7, OperatorChronicleEvent::NOTHING
    assert_equal 8, OperatorChronicleEvent::STAFF_SECRET_CREATED
    assert_equal 9, OperatorChronicleEvent::STAFF_SECRET_REMOVED
    assert_equal 10, OperatorChronicleEvent::STAFF_SECRET_UPDATED
    assert_equal 11, OperatorChronicleEvent::STEP_UP_VERIFIED
    assert_equal 12, OperatorChronicleEvent::SOCIAL_UNLINKED
    assert_equal 16, OperatorChronicleEvent::STEP_UP_FAILED
    assert_equal 17, OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED
  end

  test "has_many association with staff_chronicles" do
    association = OperatorChronicleEvent.reflect_on_association(:staff_chronicles)

    assert_equal :has_many, association.macro
    assert_equal :destroy, association.options[:dependent]
    assert_equal :event_id, association.options[:foreign_key]
  end

  test "ensure_defaults! inserts missing fixed ids" do
    OperatorChronicleEvent.ensure_defaults!

    OperatorChronicleEvent::DEFAULTS.each do |id|
      assert OperatorChronicleEvent.exists?(id: id), "expected event id #{id} to exist"
    end
    assert_includes OperatorChronicleEvent::DEFAULTS, OperatorChronicleEvent::STEP_UP_FAILED
    assert_includes OperatorChronicleEvent::DEFAULTS, OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED
  end
end
