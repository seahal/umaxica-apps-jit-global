# typed: false
# frozen_string_literal: true

module SignOutFlow
  extend ActiveSupport::Concern

  included do
    include ::PublicId
    include ::Retainable

    self.belongs_to_required_by_default = false

    attribute :requested_at, :datetime, default: -> { Time.current }

    before_validation :assign_default_status_id
    before_validation :assign_default_kind_id

    validates :status_id, presence: true, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
    validates :kind_id, presence: true, inclusion: { in: ->(record) { record.class::KIND_IDS } }
    validates :requested_at, :access_expires_at, :refresh_expires_at, presence: true
    validate :refresh_expires_at_after_access_expires_at
    validate :completed_status_has_completed_at

    scope :recent_first, -> { order(created_at: :desc) }
    scope :incomplete, -> { where.not(status_id: completed_status_id) }
  end

  class_methods do
    def status_id_for(status_name)
      self::STATUSES.fetch(status_name.to_s)
    end

    def status_name_for(status_id)
      self::STATUS_NAMES.fetch(status_id)
    end

    def status_ids_for(*status_names)
      status_names.map { |status_name| status_id_for(status_name) }
    end

    def kind_id_for(kind_name)
      self::KINDS.fetch(kind_name.to_s)
    end

    def kind_name_for(kind_id)
      self::KIND_NAMES.fetch(kind_id)
    end

    def default_status_id
      status_id_for("REQUESTED")
    end

    def default_kind_id
      kind_id_for("NOTHING")
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

  delegate :kind_id_for, to: :class

  delegate :kind_name_for, to: :class

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
    self.status_id ||= self.class.default_status_id
  end

  def assign_default_kind_id
    self.kind_id ||= self.class.default_kind_id
  end

  def refresh_expires_at_after_access_expires_at
    return if access_expires_at.blank? || refresh_expires_at.blank?
    return if access_expires_at <= refresh_expires_at

    errors.add(:refresh_expires_at, "must be after or equal to access_expires_at")
  end

  def completed_status_has_completed_at
    return unless completed?

    errors.add(:completed_at, "must be present for completed cycles") if completed_at.blank?
  end
end
