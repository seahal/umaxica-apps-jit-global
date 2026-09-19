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
#  discarded_at   :datetime         default(Infinity), not null
#  ip_address     :inet             default(#<IPAddr: IPv4:0.0.0.0/255.255.255.255>), not null
#  occurred_at    :datetime         not null
#  previous_value :text             default(""), not null
#  purged_at      :datetime         not null
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
#  index_app_preference_chronicles_on_purged_at                 (purged_at)
#  index_app_preference_chronicles_on_subject_id                (subject_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => app_preference_chronicle_events.id)
#  fk_rails_...  (level_id => app_preference_chronicle_levels.id)
#

# frozen_string_literal: true

class AppPreferenceChronicle < ChronicleRecord
  self.belongs_to_required_by_default = false

  include Retainable

  belongs_to :app_preference,
             class_name: "AppPreference",
             foreign_key: :subject_id,
             primary_key: :id,
             inverse_of: :app_preference_chronicles
  belongs_to :app_preference_chronicle_level, foreign_key: :level_id, inverse_of: :app_preference_chronicles
  belongs_to :app_preference_chronicle_event,
             class_name: "AppPreferenceChronicleEvent",
             foreign_key: "event_id",
             primary_key: "id",
             inverse_of: :app_preference_chronicles
  validates :subject_type, presence: true

  validates :event_id, length: { maximum: 255 }
  validates :level_id, length: { maximum: 255 }
  # Helper methods for compatibility
  def app_preference
    return if subject_id.blank?

    AppPreference.find(subject_id) if subject_type == "AppPreference"
  end

  def app_preference=(pref)
    self.subject_id = pref.id.to_s
    self.subject_type = "AppPreference"
  end
end
