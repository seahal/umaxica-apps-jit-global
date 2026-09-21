# typed: false
# == Schema Information
#
# Table name: org_preference_chronicles
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
#  idx_on_subject_type_subject_id_occurred_at_org_pref          (subject_type,subject_id,occurred_at)
#  index_org_preference_chronicles_on_actor_id_and_occurred_at  (actor_id,occurred_at)
#  index_org_preference_chronicles_on_actor_type_and_actor_id   (actor_type,actor_id)
#  index_org_preference_chronicles_on_event_id                  (event_id)
#  index_org_preference_chronicles_on_level_id                  (level_id)
#  index_org_preference_chronicles_on_occurred_at               (occurred_at)
#  index_org_preference_chronicles_on_purge_eligible_at                 (purge_eligible_at)
#  index_org_preference_chronicles_on_subject_id                (subject_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => org_preference_chronicle_events.id)
#  fk_rails_...  (level_id => org_preference_chronicle_levels.id)
#

# frozen_string_literal: true

class OrgPreferenceChronicle < ChronicleRecord
  self.belongs_to_required_by_default = false

  include Retainable

  # Virtual belongs_to for ERD - uses subject_id/subject_type instead of FK
  belongs_to :org_preference,
             class_name: "OrgPreference",
             foreign_key: :subject_id,
             primary_key: :id,
             inverse_of: :org_preference_chronicles
  belongs_to :actor, polymorphic: true # Helper methods for compatibility
  belongs_to :org_preference_chronicle_level, foreign_key: :level_id, inverse_of: :org_preference_chronicles
  belongs_to :org_preference_chronicle_event,
             class_name: "OrgPreferenceChronicleEvent",
             foreign_key: "event_id",
             primary_key: "id",
             inverse_of: :org_preference_chronicles
  validates :subject_type, presence: true

  validates :event_id, length: { maximum: 255 }
  validates :level_id, length: { maximum: 255 }
  before_validation :default_actor_to_preference

  def org_preference
    return if subject_id.blank?

    OrgPreference.find(subject_id) if subject_type == "OrgPreference"
  end

  def org_preference=(pref)
    self.subject_id = pref.id.to_s
    self.subject_type = "OrgPreference"
  end

  def default_actor_to_preference
    return if actor_id.present? && actor_type.present?
    return unless subject_id.present? && subject_type == "OrgPreference"

    self.actor = org_preference
  end
end
