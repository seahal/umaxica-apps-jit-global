# typed: false
# == Schema Information
#
# Table name: com_preference_chronicles
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
#  idx_on_subject_type_subject_id_occurred_at_com_pref          (subject_type,subject_id,occurred_at)
#  index_com_preference_chronicles_on_actor_id_and_occurred_at  (actor_id,occurred_at)
#  index_com_preference_chronicles_on_actor_type_and_actor_id   (actor_type,actor_id)
#  index_com_preference_chronicles_on_event_id                  (event_id)
#  index_com_preference_chronicles_on_level_id                  (level_id)
#  index_com_preference_chronicles_on_occurred_at               (occurred_at)
#  index_com_preference_chronicles_on_purge_eligible_at                 (purge_eligible_at)
#  index_com_preference_chronicles_on_subject_id                (subject_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => com_preference_chronicle_events.id)
#  fk_rails_...  (level_id => com_preference_chronicle_levels.id)
#

# frozen_string_literal: true

require "test_helper"

class ComPreferenceChronicleTest < ActiveSupport::TestCase
  fixtures :com_preferences,
           :com_preference_chronicles,
           :com_preference_chronicle_events,
           :com_preference_chronicle_levels,
           :com_preference_statuses

  setup do
    @audit = com_preference_chronicles(:one)
    @preference = com_preferences(:one)
    @audit.update!(subject_id: @preference.id) # Ensure valid link
  end

  test "uses bigint primary key" do
    assert_kind_of Integer, @audit.id
  end

  test "belongs to com_preference" do
    assert_equal @preference, @audit.com_preference
  end

  test "com_preference helper method returns nil for other subject types" do
    @audit.subject_type = "OtherType"

    assert_nil @audit.com_preference
  end

  test "can set com_preference" do
    new_pref = com_preferences(:two)
    @audit.com_preference = new_pref

    assert_equal new_pref.id, @audit.subject_id
    assert_equal "ComPreference", @audit.subject_type
    assert_equal new_pref, @audit.com_preference
  end

  test "belongs to com_preference_chronicle_level" do
    assert_equal com_preference_chronicle_levels(:info), @audit.com_preference_chronicle_level
  end

  test "belongs to com_preference_chronicle_event" do
    assert_equal com_preference_chronicle_events(:create_new_preference_token), @audit.com_preference_chronicle_event
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

  test "event_id is integer type" do
    # event_id is now bigint, not string - length validation doesn't apply
    @audit.event_id = 1

    assert_kind_of Integer, @audit.event_id
  end

  test "level_id is integer type" do
    # level_id is now bigint, not string - length validation doesn't apply
    @audit.level_id = 1

    assert_kind_of Integer, @audit.level_id
  end
end
