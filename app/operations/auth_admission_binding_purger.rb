# typed: false
# frozen_string_literal: true

# Removes admission bindings only after their parent and referenced Auth
# continuity have reached the same retention boundary. Retained sign-up Flows
# are deleted first; the Binding then precedes its own restrictive parent.
class AuthAdmissionBindingPurger
  PARENT_BINDINGS = {
    ClientOidcAuthorizationTransaction => [ClientAuthAdmissionBinding, :authorization_transaction_id],
    VisitorOidcAuthorizationTransaction => [VisitorAuthAdmissionBinding, :authorization_transaction_id],
    OperatorOidcAuthorizationTransaction => [OperatorAuthAdmissionBinding, :authorization_transaction_id],
    ClientStepUpCeremonyTransaction => [ClientAuthAdmissionBinding, :step_up_ceremony_transaction_id],
    VisitorStepUpCeremonyTransaction => [VisitorAuthAdmissionBinding, :step_up_ceremony_transaction_id],
    OperatorStepUpCeremonyTransaction => [OperatorAuthAdmissionBinding, :step_up_ceremony_transaction_id],
  }.freeze

  public

  class << self
    public

    def purge_for_parent!(parent:, now:, retention_period:)
      new(parent:, now:, retention_period:).call
    end
  end

  def initialize(parent:, now:, retention_period:)
    @parent = parent
    @now = now
    @retention_period = retention_period
    @binding_model, @parent_foreign_key = PARENT_BINDINGS.fetch(parent.class)
    validate_retention_period!
  end

  def call
    binding_model.connection_owner.connected_to(role: :writing) do
      binding_model.transaction do
        parent.with_lock do
          bindings_for_parent.lock.order(:id).to_a.each do |binding|
            retire_expired_unredeemed!(binding)
            binding.reload
            next unless eligible?(binding)
            next unless purge_sign_up_flows!(binding)

            binding_model.where(id: binding.id).delete_all
          end
          !bindings_for_parent.exists?
        end
      end
    end
  end

  private

  attr_reader :parent, :now, :retention_period, :binding_model, :parent_foreign_key

  def bindings_for_parent
    binding_model.where(parent_foreign_key => parent.id)
  end

  def retire_expired_unredeemed!(binding)
    return unless binding.redeemed_at.nil? && binding.retired_at.nil?
    return unless binding.expires_at <= now

    binding.retire!
  end

  def eligible?(binding)
    cutoff = now - retention_period
    return false unless parent.expires_at <= cutoff

    terminal_at = binding.redeemed_at || binding.retired_at
    return false unless terminal_at && terminal_at <= cutoff
    return false unless binding.expires_at <= cutoff

    auth_sessions_eligible?(binding, cutoff: cutoff)
  end

  def auth_sessions_eligible?(binding, cutoff:)
    session_ids = [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id].compact
    session_ids.uniq!
    return true if session_ids.empty?

    session_model = binding.class.auth_admission_session_class
    sessions = session_model.lock.where(id: session_ids).order(:id).to_a
    unless sessions.length == session_ids.length
      raise ActiveRecord::RecordNotFound, "admission binding references a missing Auth ceremony session"
    end

    sessions.all? do |session|
      session.expires_at <= cutoff &&
        [session.revoked_at, session.completed_at, session.cancelled_at].all? do |timestamp|
          timestamp.nil? || timestamp <= cutoff
        end
    end
  end

  def purge_sign_up_flows!(binding)
    flow_class =
      case binding
      when ClientAuthAdmissionBinding then ClientSignUpFlow
      when VisitorAuthAdmissionBinding then VisitorSignUpFlow
      when OperatorAuthAdmissionBinding then return true
      else raise ArgumentError, "unsupported sign-up admission owner"
      end
    flows = flow_class.where(auth_admission_binding_id: binding.id).order(:id).lock.to_a
    return false unless flows.all? do |flow|
      flow.sign_up_terminal? && flow.purgeable?(now) &&
        (flow.cleanup_completed? || flow.sign_up_completed?)
    end

    flow_class.where(id: flows.map(&:id)).delete_all
    true
  end

  def validate_retention_period!
    value =
      case retention_period
      when ActiveSupport::Duration then retention_period.value
      when Numeric then retention_period
      else raise ArgumentError, "retention period must be a duration or number"
      end
    raise ArgumentError, "retention period must be finite and positive" unless value.finite? && value.positive?
  end
end
