# typed: false
# frozen_string_literal: true

module SignFlowStatusBacked
  extend ActiveSupport::Concern

  included do
    before_validation :assign_default_status_id
    before_validation :sync_legacy_state_from_status

    validates :status_id, presence: true, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
    validates :step, presence: true, inclusion: { in: ->(record) { record.class::STEPS } },
                     if: ->(record) { record.class.const_defined?(:STEPS, false) }
    validates :state, presence: true, if: ->(record) { record.has_attribute?(:state) }
    validate :legacy_state_matches_status
    validate :step_matches_status
    validate :completed_status_has_completed_at
  end

  class_methods do
    def status_id_for(status_name)
      self::STATUS_NAMES.invert.fetch(status_name.to_s)
    end

    def status_name_for(status_id)
      self::STATUS_NAMES.fetch(status_id)
    end

    def status_ids_for(*status_names)
      status_names.map { |status_name| status_id_for(status_name) }
    end

    def completed_status_id
      status_id_for("COMPLETED")
    end
  end

  delegate :status_id_for, to: :class
  delegate :status_name_for, to: :class

  def status_ids_for(*status_names)
    self.class.status_ids_for(*status_names)
  end

  def completed?
    status_id == self.class.completed_status_id
  end

  def can_transition_to?(next_status)
    next_status_id = normalize_status_id(next_status)

    self.class::TRANSITIONS.fetch(status_id, []).include?(next_status_id)
  end

  private

  def normalize_status_id(status)
    return status if status.is_a?(Integer)

    self.class.status_id_for(status)
  end

  def assign_default_status_id
    self.status_id ||= self.class::STATUS_IDS.first
  end

  def sync_legacy_state_from_status
    return unless has_attribute?(:state)
    return if status_id.blank? || state.present?

    self.state = self.class::STATUS_NAMES[status_id]
  end

  def legacy_state_matches_status
    return unless has_attribute?(:state) && status_id.present?

    expected_state = self.class::STATUS_NAMES[status_id]
    errors.add(:state, "must match status_id") if expected_state.present? && state != expected_state
  end

  def step_matches_status
    return unless self.class.const_defined?(:STEPS, false)
    return if status_id.blank? || step.blank?

    expected_step = self.class::STEP_BY_STATUS_ID[status_id] if self.class.const_defined?(:STEP_BY_STATUS_ID, false)
    errors.add(:step, "must match status_id") if expected_step.present? && step != expected_step
  end

  def completed_status_has_completed_at
    return unless completed?

    errors.add(:completed_at, "must be present for completed cycles") if completed_at.blank?
  end
end
