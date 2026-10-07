# typed: false
# frozen_string_literal: true

module RetentionHoldState
  extend ActiveSupport::Concern

  HOLD_KINDS = %w(legal_hold).freeze
  REASON_CODES = %w(legal_hold security_investigation billing_dispute abuse_investigation court_order other).freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include PublicId
    include Retainable

    before_validation :assign_retention_hold_defaults, on: :create

    validates :hold_kind, inclusion: { in: HOLD_KINDS }
    validates :reason_code, inclusion: { in: REASON_CODES }
    validates :status_id, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
    validates :applied_at, presence: true

    scope :active_at,
          lambda { |now = Time.current|
            where(status_id: status_id_for("ACTIVE"))
              .where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(now)))
          }
  end

  class_methods do
    def status_id_for(status_name)
      self::STATUSES.fetch(status_name.to_s)
    end

    def status_name_for(status_id)
      self::STATUS_NAMES.fetch(status_id)
    end
  end

  def active_at?(now = Time.current)
    status_id == self.class.status_id_for("ACTIVE") && (expires_at.blank? || expires_at > now)
  end

  private

  def assign_retention_hold_defaults
    self.class::STATUS_MODEL.ensure_defaults!
    self.hold_kind = "legal_hold" if hold_kind.blank?
    self.reason_code = "legal_hold" if reason_code.blank?
    self.status_id ||= self.class.status_id_for("ACTIVE")
    self.applied_at ||= Time.current
  end
end
