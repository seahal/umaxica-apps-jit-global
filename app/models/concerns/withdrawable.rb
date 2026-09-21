# typed: false
# frozen_string_literal: true

# Shared withdraw/recovery logic for accounts (Client, Operator, Visitor)
module Withdrawable
  extend ActiveSupport::Concern

  # Deterministic recovery window: use 31 days to match product requirement.
  WITHDRAWAL_RECOVERY_PERIOD = 31.days
  WITHDRAWAL_RECOVERY_DELAY = 1.hour
  WITHDRAWAL_EARLY_TERMINATION_DELAY = 7.days

  included do
    scope :withdrawn, -> { where.not(withdrawn_at: nil) }
  end

  def withdrawn?
    withdrawn_at.present? && withdrawn_at < Float::INFINITY
  end

  def active?
    !withdrawn? && !closing? && !suspended? && !terminated?
  end

  def closing?
    withdrawal_started? && !suspended? && !terminated?
  end

  def withdrawal_started?
    respond_to?(:withdrawal_started_at) && withdrawal_started_at.present?
  end

  def withdrawal_in_progress?
    closing? || suspended?
  end

  def deactivated?
    respond_to?(:deactivated_at) && deactivated_at.present?
  end

  def suspended?
    return false unless deactivated?
    return false if terminated?

    purge_eligible_at.blank? || infinite_time?(purge_eligible_at) || purge_eligible_at.future?
  end

  def terminated?
    return true if respond_to?(:terminated_at) && terminated_at.present?

    purge_eligible_at.present? && !infinite_time?(purge_eligible_at) && !purge_eligible_at.future?
  end

  def recovery_deadline
    return purge_eligible_at if deactivated? && purge_eligible_at.present? && !infinite_time?(purge_eligible_at)

    nil
  end

  def can_recover?
    return false if recovery_deadline.blank?
    return Time.current < recovery_deadline if recovery_available_at.blank?

    Time.current >= recovery_available_at && Time.current < recovery_deadline
  end

  def recovery_available_at
    return nil if deactivated_at.blank?

    deactivated_at + WITHDRAWAL_RECOVERY_DELAY
  end

  def early_termination_available_at
    return nil if deactivated_at.blank?

    deactivated_at + WITHDRAWAL_EARLY_TERMINATION_DELAY
  end

  def early_terminatable?
    return false unless suspended?
    return false if early_termination_available_at.blank?

    Time.current >= early_termination_available_at
  end

  def permanently_deletable?
    terminated?
  end

  private

  def infinite_time?(value)
    value.respond_to?(:infinite?) && value.infinite?
  end
end
