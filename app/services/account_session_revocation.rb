# typed: false
# frozen_string_literal: true

class AccountSessionRevocation < ApplicationService
  Result = Data.define(:event, :revoked_count)

  SUPPORTED_ACCOUNT_CLASSES = [Client, Visitor, Operator].freeze
  EVENT_TYPE_BY_OPERATION = {
    emergency_revoke: AccountAccessEvent::EVENT_TYPE_EMERGENCY_SESSION_REVOKE,
    purge: AccountAccessEvent::EVENT_TYPE_SESSION_PURGE,
  }.freeze
  LOGOUT_REASON_BY_OPERATION = {
    emergency_revoke: "operator_emergency_session_revoke",
    purge: "operator_session_purge",
  }.freeze

  def self.emergency_revoke!(account:, operator:, reason_code:, reason_note: nil, ticket_id: nil)
    new(
      operation: :emergency_revoke,
      account: account,
      operator: operator,
      reason_code: reason_code,
      reason_note: reason_note,
      ticket_id: ticket_id,
    ).call
  end

  def self.purge!(account:, operator:, reason_code:, reason_note: nil, ticket_id: nil)
    new(
      operation: :purge,
      account: account,
      operator: operator,
      reason_code: reason_code,
      reason_note: reason_note,
      ticket_id: ticket_id,
    ).call
  end

  def initialize(operation:, account:, operator:, reason_code:, reason_note: nil, ticket_id: nil)
    super()
    @operation = operation
    @account = account
    @operator = operator
    @reason_code = reason_code
    @reason_note = reason_note
    @ticket_id = ticket_id
  end

  def call
    validate_inputs!

    now = Time.current
    tokens = not_revoked_tokens.to_a
    tokens.each do |token|
      AuthenticationLogoutCurrentSession.call(
        resource: account,
        token: token,
        reason: logout_reason,
        cause: "browser_logout", # D-173
      )
    end

    event = create_event!(
      occurred_at: now,
      revoked_count: tokens.length,
      token_classes: token_class_counts(tokens),
    )
    Result.new(event:, revoked_count: tokens.length)
  end

  private

  attr_reader :operation, :account, :operator, :reason_code, :reason_note, :ticket_id

  def validate_inputs!
    raise ArgumentError, "Unsupported operation" unless EVENT_TYPE_BY_OPERATION.key?(operation)
    raise ArgumentError, "Unsupported account type" unless supported_account?
    raise ArgumentError, "operator must be an Operator" unless operator.is_a?(Operator)
    return if AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES.include?(reason_code)

    raise ArgumentError, "reason_code is invalid"
  end

  def supported_account?
    SUPPORTED_ACCOUNT_CLASSES.any? { |klass| account.is_a?(klass) }
  end

  def not_revoked_tokens
    AuthenticationSessionRevoker.tokens_for(account).not_revoked
  end

  def logout_reason
    LOGOUT_REASON_BY_OPERATION.fetch(operation)
  end

  def event_type
    EVENT_TYPE_BY_OPERATION.fetch(operation)
  end

  def token_class_counts(tokens)
    tokens.each_with_object(Hash.new(0)) { |token, counts| counts[token.class.name] += 1 }
  end

  def access_state
    account.access_state
  end

  def create_event!(occurred_at:, revoked_count:, token_classes:)
    ChronicleRecord.connected_to(role: :writing) do
      AccountAccessEvent.create!(
        account_type: account.class.name,
        account_id: account.id,
        event_type: event_type,
        previous_access_state: access_state,
        next_access_state: access_state,
        operator_id: operator.id,
        reason_code: reason_code,
        reason_note: reason_note,
        ticket_id: ticket_id,
        occurred_at: occurred_at,
        metadata: {
          "operation" => operation.to_s,
          "revoked_count" => revoked_count,
          "token_classes" => token_classes,
        },
      )
    end
  end
end
