# typed: false
# frozen_string_literal: true

class AdministrativeAccessLock < ApplicationService
  SUPPORTED_ACCOUNT_CLASSES = [Client, Visitor, Operator].freeze

  class LastEnabledOperatorError < StandardError; end

  def self.lock!(account:, operator:, reason_code:, reason_note: nil, ticket_id: nil, metadata: {})
    new(account:, operator:, reason_code:, reason_note:, ticket_id:, metadata:).lock!
  end

  def self.unlock!(account:, operator:, reason_code:, reason_note: nil, ticket_id: nil, metadata: {})
    new(account:, operator:, reason_code:, reason_note:, ticket_id:, metadata:).unlock!
  end

  def initialize(account:, operator:, reason_code:, reason_note: nil, ticket_id: nil, metadata: {})
    super()
    @account = account
    @operator = operator
    @reason_code = reason_code
    @reason_note = reason_note
    @ticket_id = ticket_id
    @metadata = metadata
  end

  def lock!
    validate_inputs!
    now = Time.current
    previous_state = nil

    account.class.transaction do
      account.lock!
      ensure_operator_can_be_locked! if account.is_a?(Operator)
      previous_state = account.access_state
      account.update!(
        access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
        admin_locked_at: now,
        admin_locked_by_operator_id: operator.id,
        admin_locked_reason_code: reason_code,
        admin_locked_reason_note: reason_note,
        token_valid_after_at: now,
      )
    end

    revoke_sessions!
    create_event!(
      event_type: lock_event_type(previous_state),
      previous_state: previous_state,
      next_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      occurred_at: now,
    )
    account
  end

  def unlock!
    validate_inputs!
    now = Time.current
    previous_state = nil

    account.class.transaction do
      account.lock!
      previous_state = account.access_state
      account.update!(
        access_state: AdministrativeAccessLockable::ACCESS_STATE_ENABLED,
        admin_locked_at: nil,
        admin_locked_by_operator_id: nil,
        admin_locked_reason_code: nil,
        admin_locked_reason_note: nil,
        token_valid_after_at: now,
        reactivated_at: now,
      )
    end

    create_event!(
      event_type: AccountAccessEvent::EVENT_TYPE_ADMIN_UNLOCK,
      previous_state: previous_state,
      next_state: AdministrativeAccessLockable::ACCESS_STATE_ENABLED,
      occurred_at: now,
    )
    account
  end

  private

  attr_reader :account, :operator, :reason_code, :reason_note, :ticket_id, :metadata

  def validate_inputs!
    supported_account = SUPPORTED_ACCOUNT_CLASSES.any? { |klass| account.is_a?(klass) }
    raise ArgumentError, "Unsupported account type" unless supported_account
    raise ArgumentError, "operator must be an Operator" unless operator.is_a?(Operator)
    unless AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES.include?(reason_code)
      raise ArgumentError, "reason_code is invalid"
    end
    raise ArgumentError, "metadata must be a Hash" unless metadata.is_a?(Hash)
  end

  def lock_event_type(previous_state)
    if previous_state == AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED
      return AccountAccessEvent::EVENT_TYPE_ADMIN_LOCK_REAFFIRMED
    end

    AccountAccessEvent::EVENT_TYPE_ADMIN_LOCK
  end

  def revoke_sessions!
    AuthenticationSessionRevoker.tokens_for(account).not_revoked.find_each(&:revoke!)
  end

  def create_event!(event_type:, previous_state:, next_state:, occurred_at:)
    ChronicleRecord.connected_to(role: :writing) do
      AccountAccessEvent.create!(
        account_type: account.class.name,
        account_id: account.id,
        event_type: event_type,
        previous_access_state: previous_state,
        next_access_state: next_state,
        operator_id: operator.id,
        reason_code: reason_code,
        reason_note: reason_note,
        ticket_id: ticket_id,
        occurred_at: occurred_at,
        metadata: metadata,
      )
    end
  end

  def ensure_operator_can_be_locked!
    return unless account.access_enabled?

    remaining_enabled_operator_exists =
      Operator
        .where(access_state: AdministrativeAccessLockable::ACCESS_STATE_ENABLED)
        .where(deactivated_at: nil, withdrawn_at: nil)
        .where(Operator.arel_table[:discard_at].gt(Time.current))
        .where.not(id: account.id)
        .exists?
    return if remaining_enabled_operator_exists

    raise LastEnabledOperatorError, "Cannot admin-lock the last enabled operator"
  end
end
