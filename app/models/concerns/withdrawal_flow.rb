# typed: false
# frozen_string_literal: true

module WithdrawalFlow
  extend ActiveSupport::Concern

  included do
    include ::PublicId
    include ::Retainable

    attribute :began_at, :datetime, default: -> { Time.current }

    before_validation :ensure_withdrawal_flow_reference_defaults
    before_validation :assign_default_status_id

    after_create :record_initial_withdrawal_event

    validates :status_id, presence: true, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
    validates :began_at, presence: true
    validate :terminal_status_has_completed_at
    validate :failed_status_has_failed_at

    scope :recent_first, -> { order(created_at: :desc) }
    scope :active,
          -> do
            where(status_id: status_ids_for("REQUESTED", "CLOSING", "DISCARDED"))
              .where(arel_table[:discard_at].gt(Time.current))
          end
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

    def default_status_id
      status_id_for("REQUESTED")
    end

    def terminal_status_ids
      status_ids_for("RECOVERED", "TERMINATED")
    end
  end

  delegate :status_id_for, to: :class

  delegate :status_name_for, to: :class

  def status_ids_for(*status_names)
    self.class.status_ids_for(*status_names)
  end

  def terminal?
    self.class.terminal_status_ids.include?(status_id)
  end

  def failed?
    status_id == status_id_for("FAILED")
  end

  def can_transition_to?(next_status)
    next_status_id = normalize_status_id(next_status)

    self.class::TRANSITIONS.fetch(status_id, []).include?(next_status_id)
  end

  def record_withdrawal_event!(from_status_id:, to_status_id:, occurred_at:, token_public_id: nil, reason: nil,
                               metadata: {})
    attrs = {
      withdrawal_flow_foreign_key => id,
      actor_foreign_key => public_send(actor_foreign_key),
      :from_status_id => from_status_id,
      :to_status_id => to_status_id,
      :occurred_at => occurred_at,
      :token_public_id => token_public_id.to_s,
      :reason => reason.to_s,
      :metadata => metadata || {},
    }

    operation = -> { self.class::EVENT_MODEL.create!(attrs) }
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  private

  def normalize_status_id(status)
    return status if status.is_a?(Integer)

    self.class.status_id_for(status)
  end

  def ensure_withdrawal_flow_reference_defaults
    self.class::STATUS_MODEL.ensure_defaults!
  end

  def assign_default_status_id
    self.status_id ||= self.class.default_status_id
  end

  def record_initial_withdrawal_event
    return if status_id == status_id_for("NOTHING")

    record_withdrawal_event!(
      from_status_id: status_id_for("NOTHING"),
      to_status_id: status_id,
      occurred_at: began_at || created_at || Time.current,
    )
  end

  def actor_foreign_key
    self.class::ACTOR_FOREIGN_KEY
  end

  def withdrawal_flow_foreign_key
    self.class::WITHDRAWAL_CYCLE_FOREIGN_KEY
  end

  def terminal_status_has_completed_at
    return unless terminal?

    errors.add(:completed_at, "must be present for terminal withdrawal cycles") if completed_at.blank?
  end

  def failed_status_has_failed_at
    return unless failed?

    errors.add(:failed_at, "must be present for failed withdrawal cycles") if failed_at.blank?
  end
end
