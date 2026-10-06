# typed: false
# frozen_string_literal: true

module SignInFlow
  extend ActiveSupport::Concern

  include SignFlow
  include FlowBase

  included do
    cycle_status_column :state_id

    before_validation :assign_default_state_id

    validates :state_id, presence: true, inclusion: { in: ->(record) { record.class::STATE_IDS } }
    validate :completed_state_has_completed_at
  end

  class_methods do
    def state_id_for(state_name)
      self::STATE_NAMES.invert.fetch(state_name.to_s)
    end

    def state_name_for(state_id)
      self::STATE_NAMES.fetch(state_id)
    end

    def state_ids_for(*state_names)
      state_names.map { |state_name| state_id_for(state_name) }
    end

    def completed_state_id
      state_id_for("COMPLETED")
    end
  end

  delegate :state_id_for, to: :class
  delegate :state_name_for, to: :class

  def state_ids_for(*state_names)
    self.class.state_ids_for(*state_names)
  end

  def completed?
    state_id == self.class.completed_state_id
  end

  def can_transition_to?(next_state)
    next_state_id = normalize_state_id(next_state)

    self.class::TRANSITIONS.fetch(state_id, []).include?(next_state_id)
  end

  private

  def normalize_state_id(state)
    return state if state.is_a?(Integer)

    self.class.state_id_for(state)
  end

  def assign_default_state_id
    self.state_id ||= self.class::STATE_IDS.first
  end

  def completed_state_has_completed_at
    return unless completed?

    errors.add(:completed_at, "must be present for completed cycles") if completed_at.blank?
  end
end
