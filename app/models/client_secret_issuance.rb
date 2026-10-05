# frozen_string_literal: true

class ClientSecretIssuance < AppZenithRecord
  include PublicId

  belongs_to :client

  attr_readonly :client_id, :origin_operation_id, :origin, :attempt_number,
                :browser_session_ref, :sign_up_flow_ref, :planned_count, :expires_at

  validate :cancellation_is_immutable, on: :update
  validate :cancellation_has_source_audit, on: :update
  validate :confirmation_is_immutable, on: :update
  validate :presentation_is_immutable, on: :update
  validate :signup_completion_has_source_audit, on: :update

  public

  def write_attribute(name, value)
    verify_persisted_fact_assignment!(name, value)
    super
  end

  def _write_attribute(name, value)
    verify_persisted_fact_assignment!(name, value)
    super
  end

  def state(at:)
    verify_state_facts!
    return :omitted if planned_count.zero?
    return :confirmed if confirmed_at
    return :canceled if canceled_at
    return :expired if expires_at <= at

    presented_at ? :pending_confirmation : :pending_presentation
  end

  def reserved_count(at:)
    case state(at: at)
    when :pending_presentation, :pending_confirmation
      planned_count
    when :omitted, :confirmed, :canceled, :expired
      0
    end
  end

  def cancel_for_withdrawal!(at:, purge_at:)
    unless (at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)) &&
        (purge_at.is_a?(Time) || purge_at.is_a?(ActiveSupport::TimeWithZone)) && purge_at > at
      raise ArgumentError, "Secret withdrawal cancellation requires ordered timestamps"
    end

    client.with_lock do
      raise ArgumentError, "Secret withdrawal cancellation requires a terminated Client" unless client.terminated?

      with_lock do
        return self if confirmed_at || canceled_at || planned_count.zero?

        context = ActorValuesContext.empty.with(subject: client, actor_type: :client, tld: :app, surface: :base)
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: client.public_id, operation_ref: origin_operation_id,
          occurred_at: at, event_name: "secret.issuance_canceled", reason: "withdrawal", item_count: planned_count,
        )
        update!(canceled_at: at, encrypted_payload: nil, discard_at: at, purge_eligible_at: purge_at)
      end
    end
    self
  end

  private

  def verify_persisted_fact_assignment!(name, value = nil)
    return unless persisted?

    recorded =
      case name.to_s
      when "presented_at"
        presented_at_in_database
      when "confirmed_at"
        confirmed_at_in_database
      when "signup_completed_at"
        signup_completed_at_in_database
      when "canceled_at"
        canceled_at_in_database
      end
    raise ActiveRecord::ReadonlyAttributeError, name.to_s if recorded && recorded != value
  end

  # Direct persistence skips validations, but it must preserve the same
  # irreversible presentation and terminal facts as ordinary assignment.
  def verify_readonly_attribute(name)
    verify_persisted_fact_assignment!(name)
    super
  end

  def signup_completion_has_source_audit
    return unless will_save_change_to_signup_completed_at?

    if signup_completed_at_in_database || sign_up_flow_ref.nil? || signup_completed_at.nil?
      errors.add(:signup_completed_at, "requires an immutable signup completion fact")
      return
    end
    recorded = ClientSecretAuditOutbox.exists?(
      client_ref: client.public_id, operation_ref: origin_operation_id,
      event_name: "secret.signup_completed", occurred_at: signup_completed_at, item_count: planned_count,
    )
    errors.add(:signup_completed_at, "requires its matching source audit transaction") unless recorded
  end

  def confirmation_is_immutable
    return unless confirmed_at_in_database && will_save_change_to_confirmed_at?

    errors.add(:confirmed_at, "cannot change a terminal storage declaration fact")
  end

  def presentation_is_immutable
    return unless presented_at_in_database && will_save_change_to_presented_at?

    errors.add(:presented_at, "cannot change a completed presentation fact")
  end

  def cancellation_is_immutable
    return unless canceled_at_in_database && will_save_change_to_canceled_at?

    errors.add(:canceled_at, "cannot change a terminal cancellation fact")
  end

  def cancellation_has_source_audit
    return unless canceled_at && canceled_at_in_database.nil? && will_save_change_to_canceled_at?

    recorded = ClientSecretAuditOutbox.exists?(
      client_ref: client.public_id, credential_ref: nil, operation_ref: origin_operation_id,
      event_name: "secret.issuance_canceled", reason: %w(flow_canceled withdrawal payload_unavailable),
      occurred_at: canceled_at,
      actor_type: "Client", actor_id: client_id, actor_public_ref: client.public_id, item_count: planned_count,
    )
    return if recorded

    errors.add(:canceled_at, "requires its matching source audit transaction")
  end

  def verify_state_facts!
    unless planned_count.is_a?(Integer) && planned_count.between?(0, 2)
      raise ArgumentError, "issuance requires a planned count between zero and two"
    end

    if planned_count.zero?
      if expires_at || presented_at || confirmed_at || canceled_at || encrypted_payload
        raise ArgumentError, "omission cannot contain delivery or expiry facts"
      end

      return
    end

    raise ArgumentError, "positive issuance requires an expiry" unless expires_at
    raise ArgumentError, "confirmation and cancellation conflict" if confirmed_at && canceled_at
    raise ArgumentError, "presentation must precede expiry" if presented_at && presented_at >= expires_at
    return unless confirmed_at
    return if presented_at && confirmed_at >= presented_at && confirmed_at < expires_at

    raise ArgumentError, "confirmation requires presentation before expiry"

  end
end
