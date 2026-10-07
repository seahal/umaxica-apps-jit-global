# typed: false
# frozen_string_literal: true

module PrivacyRequestState
  extend ActiveSupport::Concern

  REQUEST_KINDS = %w(erasure restriction third_party_stop).freeze
  JURISDICTIONS = %w(jp us_ca eu_eea unknown).freeze
  REQUEST_SOURCES = %w(self_service support_manual authorized_agent guardian).freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include PublicId
    include Retainable

    before_validation :assign_privacy_request_defaults, on: :create

    validates :request_kind, inclusion: { in: REQUEST_KINDS }
    validates :jurisdiction, inclusion: { in: JURISDICTIONS }
    validates :request_source, inclusion: { in: REQUEST_SOURCES }
    validates :status_id, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
    validates :received_at, :response_due_at, presence: true

    scope :open_for_recovery_block,
          -> {
            where(
              status_id: status_ids_for(
                "VERIFIED", "PROCESSING", "COMPLETED", "BLOCKED_BY_LEGAL_HOLD",
                "PARTIALLY_DENIED",
              ),
            )
          }
    scope :open_for_hold_block,
          -> { where(status_id: status_ids_for("RECEIVED", "VERIFICATION_REQUIRED", "VERIFIED", "PROCESSING")) }
    scope :received, -> { where(status_id: status_id_for("RECEIVED")) }
  end

  class_methods do
    def status_id_for(status_name)
      self::STATUSES.fetch(status_name.to_s)
    end

    def status_ids_for(*status_names)
      status_names.map { |status_name| status_id_for(status_name) }
    end

    def status_name_for(status_id)
      self::STATUS_NAMES.fetch(status_id)
    end
  end

  def received?
    status_id == self.class.status_id_for("RECEIVED")
  end

  def recovery_blocking?
    self.class.status_ids_for(
      "VERIFIED",
      "PROCESSING",
      "COMPLETED",
      "BLOCKED_BY_LEGAL_HOLD",
      "PARTIALLY_DENIED",
    ).include?(status_id)
  end

  def cancel_from_recovery!(now: Time.current)
    return unless received?

    update!(status_id: self.class.status_id_for("CANCELLED"), cancelled_at: now)
  end

  def block_by_legal_hold!(retention_exception_code: "legal_hold", now: Time.current)
    update!(
      status_id: self.class.status_id_for("BLOCKED_BY_LEGAL_HOLD"),
      legal_hold_blocked_at: legal_hold_blocked_at.presence || now,
      retention_exception_code: retention_exception_code.to_s,
    )
  end

  private

  def assign_privacy_request_defaults
    self.class::STATUS_MODEL.ensure_defaults!
    now = Time.current
    self.request_kind = "erasure" if request_kind.blank?
    self.request_source = "self_service" if request_source.blank?
    self.jurisdiction = "unknown" if jurisdiction.blank?
    self.status_id ||= self.class.status_id_for("RECEIVED")
    self.received_at ||= now
    self.response_due_at ||= PrivacyRequestDueDate.due_at(jurisdiction: jurisdiction, received_at: received_at)
  end
end
