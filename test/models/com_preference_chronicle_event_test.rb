# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ComPreferenceChronicleEventTest < ActiveSupport::TestCase
  fixtures :com_preference_chronicle_events

  test "has correct NOTHING constant" do
    assert_equal 0, ComPreferenceChronicleEvent::NOTHING
  end

  test "can load nothing status from db" do
    status = ComPreferenceChronicleEvent.find(ComPreferenceChronicleEvent::NOTHING)

    assert_equal 0, status.id
  end

  test "includes all default ids" do
    ids = ComPreferenceChronicleEvent.pluck(:id)

    assert_empty(ComPreferenceChronicleEvent::DEFAULTS - ids)
  end
end
