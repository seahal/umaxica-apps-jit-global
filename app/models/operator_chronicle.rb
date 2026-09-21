# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_chronicles
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
#  level_id       :bigint           default(1), not null
#  subject_id     :bigint           not null
#
# Indexes
#
#  idx_on_subject_type_subject_id_occurred_at_2e96c29236  (subject_type,subject_id,occurred_at)
#  index_operator_chronicles_on_actor_id_and_occurred_at  (actor_id,occurred_at)
#  index_operator_chronicles_on_event_id                  (event_id)
#  index_operator_chronicles_on_level_id                  (level_id)
#  index_operator_chronicles_on_occurred_at               (occurred_at)
#  index_operator_chronicles_on_purge_eligible_at                 (purge_eligible_at)
#  index_operator_chronicles_on_subject_id                (subject_id)
#  index_staff_activities_on_actor                        (actor_type,actor_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => operator_chronicle_events.id)
#  fk_rails_...  (level_id => operator_chronicle_levels.id)
#

class OperatorChronicle < ChronicleRecord
  include Retainable

  belongs_to :staff_chronicle_event, class_name: "OperatorChronicleEvent", foreign_key: :event_id,
                                     inverse_of: :staff_chronicles
  belongs_to :actor, polymorphic: true
  belongs_to :staff_chronicle_level, class_name: "OperatorChronicleLevel", foreign_key: :level_id,
                                     inverse_of: :staff_chronicles
  # subject_id/subject_type for cross-DB compatibility (no FK)
  validates :subject_id, presence: true
  validates :subject_type, presence: true

  attribute :level_id, default: OperatorChronicleLevel::NOTHING

  scope :recent_activity_first, -> { order(arel_table[:occurred_at].desc, arel_table[:created_at].desc) }

  validates :event_id, numericality: { only_integer: true }, allow_nil: true
  validates :level_id, numericality: { only_integer: true }, allow_nil: true
  # Validate that event_id exists in staff_chronicle_events table
  validate :event_id_must_exist
  before_validation :default_actor_to_subject
  # Helper methods for compatibility with existing code
  before_create :set_timestamp

  def set_timestamp
    self.timestamp ||= Time.current
  end

  def staff
    Operator.find(subject_id) if subject_type == "Operator"
  end

  def staff=(staff)
    self.subject_id = staff.id.to_s
    self.subject_type = "Operator"
  end

  # Alias for backward compatibility
  alias_attribute :timestamp, :occurred_at

  def event_id_must_exist
    return if event_id.blank?

    # Always use writing role to check event existence (avoid read replica lag)
    operation =
      lambda do
        ChronicleRecord.connected_to(role: :writing) do
          OperatorChronicleEvent.exists?(id: event_id)
        end
      end

    exists = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call

    return if exists

    errors.add(:event_id, "must reference a valid staff audit event")
  end

  def default_actor_to_subject
    return if actor_id.present? && actor_type.present?
    return unless subject_id.present? && subject_type.present?

    self.actor_id = subject_id
    self.actor_type = subject_type
  end

  encrypts :previous_value
end
