# typed: false
# == Schema Information
#
# Table name: app_preference_chronicles
# Database name: chronicle
#
#  id             :bigint           not null, primary key
#  actor_type     :text             default(""), not null
#  context        :jsonb            not null
#  current_value  :text             default(""), not null
#  discard_at   :datetime         default(Infinity), not null
#  ip_address     :inet             default(#<IPAddr: IPv4:0.0.0.0/255.255.255.255>), not null
#  occurred_at    :datetime         not null
#  previous_value :text             default(""), not null
#  purge_eligible_at      :datetime         not null
#  subject_type   :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  actor_id       :bigint           default(0), not null
#  event_id       :bigint           default(0), not null
#  level_id       :bigint           default(0), not null
#  subject_id     :bigint           not null
#
# Indexes
#
#  idx_on_subject_type_subject_id_occurred_at_app_pref          (subject_type,subject_id,occurred_at)
#  index_app_preference_chronicles_on_actor_id_and_occurred_at  (actor_id,occurred_at)
#  index_app_preference_chronicles_on_event_id                  (event_id)
#  index_app_preference_chronicles_on_level_id                  (level_id)
#  index_app_preference_chronicles_on_occurred_at               (occurred_at)
#  index_app_preference_chronicles_on_purge_eligible_at                 (purge_eligible_at)
#  index_app_preference_chronicles_on_subject_id                (subject_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => app_preference_chronicle_events.id)
#  fk_rails_...  (level_id => app_preference_chronicle_levels.id)
#

# frozen_string_literal: true

require "test_helper"

class AppPreferenceChronicleTest < ActiveSupport::TestCase
  fixtures :app_preferences,
           :app_preference_chronicles,
           :app_preference_chronicle_events,
           :app_preference_chronicle_levels,
           :app_preference_statuses

  setup do
    @audit = app_preference_chronicles(:one)
    @preference = app_preferences(:one)
  end

  test "uses bigint primary key" do
    assert_kind_of Integer, @audit.id
  end

  test "belongs to app_preference" do
    assert_equal @preference, @audit.app_preference
  end

  test "can set app_preference" do
    new_pref = app_preferences(:two)
    @audit.app_preference = new_pref

    assert_equal new_pref.id, @audit.subject_id
    assert_equal "AppPreference", @audit.subject_type
    assert_equal new_pref, @audit.app_preference
  end

  test "belongs to app_preference_chronicle_level" do
    assert_equal app_preference_chronicle_levels(:info), @audit.app_preference_chronicle_level
  end

  test "belongs to app_preference_chronicle_event" do
    assert_equal app_preference_chronicle_events(:create_new_preference_token), @audit.app_preference_chronicle_event
  end

  test "validates presence of subject_id" do
    @audit.subject_id = nil

    assert_raises(ActiveRecord::NotNullViolation) { @audit.save!(validate: false) }
  end

  test "validates presence of subject_type" do
    @audit.subject_type = nil

    assert_not @audit.valid?
    assert_includes @audit.errors[:subject_type], I18n.t("errors.messages.blank")
  end

  test "app_preference helper method returns nil when subject_type is not AppPreference" do
    @audit.subject_type = "SomeOtherType"

    assert_nil @audit.app_preference
  end
end
