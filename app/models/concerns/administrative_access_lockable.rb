# typed: false
# frozen_string_literal: true

module AdministrativeAccessLockable
  extend ActiveSupport::Concern

  ACCESS_STATE_ENABLED = "enabled"
  ACCESS_STATE_ADMIN_LOCKED = "admin_locked"
  ACCESS_STATES = [ACCESS_STATE_ENABLED, ACCESS_STATE_ADMIN_LOCKED].freeze

  ADMIN_LOCK_REASON_CODES = %w(
    abuse
    security_incident
    chargeback
    terms_violation
    support_request
    legal_hold
    operator_error_recovery
    other
  ).freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    attribute :access_state, :string, default: ACCESS_STATE_ENABLED

    validates :access_state, presence: true, inclusion: { in: ACCESS_STATES }
    validates :admin_locked_reason_code, inclusion: { in: ADMIN_LOCK_REASON_CODES }, allow_nil: true,
                                         if: :admin_locked_reason_code_column?
    validate :administrative_lock_columns_are_consistent
  end

  def access_enabled?
    access_state == ACCESS_STATE_ENABLED
  end

  def admin_locked?
    access_state == ACCESS_STATE_ADMIN_LOCKED
  end

  def access_locked?
    admin_locked?
  end

  def access_token_stale_for_administrative_lock?(payload)
    threshold = administrative_lock_column_value(:token_valid_after_at)
    return false if threshold.blank?

    issued_at = payload["iat"]
    return true if issued_at.blank?

    Time.zone.at(issued_at.to_i) < threshold
  end

  private

  def administrative_lock_columns_are_consistent
    return unless access_state_column?

    if admin_locked?
      errors.add(:admin_locked_at, "must be present when access is admin locked") if admin_locked_at.blank?
      errors.add(
        :admin_locked_by_operator_id,
        "must be present when access is admin locked",
      ) if admin_locked_by_operator_id.blank?
      errors.add(
        :admin_locked_reason_code,
        "must be present when access is admin locked",
      ) if admin_locked_reason_code.blank?
    elsif administrative_lock_metadata_present?
      errors.add(:access_state, "must be admin_locked when lock metadata is present")
    end
  end

  def administrative_lock_metadata_present?
    administrative_lock_column_value(:admin_locked_at).present? ||
      administrative_lock_column_value(:admin_locked_by_operator_id).present? ||
      administrative_lock_column_value(:admin_locked_reason_code).present? ||
      administrative_lock_column_value(:admin_locked_reason_note).present?
  end

  def administrative_lock_column_value(column_name)
    return unless respond_to?(:has_attribute?) && has_attribute?(column_name)

    public_send(column_name)
  end

  def access_state_column?
    respond_to?(:has_attribute?) && has_attribute?(:access_state)
  end

  def admin_locked_reason_code_column?
    respond_to?(:has_attribute?) && has_attribute?(:admin_locked_reason_code)
  end
end
