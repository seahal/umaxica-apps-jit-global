# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: app_preference_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AppPreferenceChronicleEventTest < ActiveSupport::TestCase
  fixtures :app_preference_chronicle_events

  test "includes all default ids" do
    ids = AppPreferenceChronicleEvent.pluck(:id)

    assert_empty(AppPreferenceChronicleEvent::DEFAULTS - ids)
  end
end
