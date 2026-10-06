# typed: false
# frozen_string_literal: true

# Removes admission bindings only after their parent and referenced Auth
# continuity have reached the same retention boundary. Bindings are deleted
# before their parent rows because every parent foreign key is restrictive.
class AuthAdmissionBindingPurger
  PARENT_BINDINGS = {
    ClientSignInFlow => [ClientAuthAdmissionBinding, :sign_in_flow_id],
    VisitorSignInFlow => [VisitorAuthAdmissionBinding, :sign_in_flow_id],
    OperatorSignInFlow => [OperatorAuthAdmissionBinding, :sign_in_flow_id],
    ClientOidcAuthorizationTransaction => [ClientAuthAdmissionBinding, :authorization_transaction_id],
    VisitorOidcAuthorizationTransaction => [VisitorAuthAdmissionBinding, :authorization_transaction_id],
    OperatorOidcAuthorizationTransaction => [OperatorAuthAdmissionBinding, :authorization_transaction_id],
    ClientStepUpCeremonyTransaction => [ClientAuthAdmissionBinding, :step_up_ceremony_transaction_id],
    VisitorStepUpCeremonyTransaction => [VisitorAuthAdmissionBinding, :step_up_ceremony_transaction_id],
    OperatorStepUpCeremonyTransaction => [OperatorAuthAdmissionBinding, :step_up_ceremony_transaction_id],
  }.freeze

  public

  def self.purge_for_parent!(parent:, now:, retention_period:)
    new(parent:, now:, retention_period:).call
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
      bindings_for_parent.lock.order(:id).to_a.each do |binding|
        retire_expired_unredeemed!(binding)
        binding.reload
        next unless eligible?(binding)

        binding_model.where(id: binding.id).delete_all
      end
    end

    !bindings_for_parent.exists?
  end

  private

  attr_reader :parent, :now, :retention_period, :binding_model, :parent_foreign_key

  def bindings_for_parent
    binding_model.where(parent_foreign_key => parent.id)
  end

  def retire_expired_unredeemed!(binding)
    return unless binding.redeemed_at.nil? && binding.retired_at.nil?
    return unless binding.expires_at <= now

    binding.retire!(now: now)
  end

  def eligible?(binding)
    cutoff = now - retention_period
    terminal_at = binding.redeemed_at || binding.retired_at
    return false unless terminal_at && terminal_at <= cutoff
    return false unless binding.expires_at <= cutoff

    auth_sessions_eligible?(binding, cutoff: cutoff)
  end

  def auth_sessions_eligible?(binding, cutoff:)
    session_ids = [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id].compact.uniq
    return true if session_ids.empty?

    session_model = binding.class.auth_admission_session_class
    sessions = session_model.lock.where(id: session_ids).order(:id).to_a
    unless sessions.length == session_ids.length
      raise ActiveRecord::RecordNotFound, "admission binding references a missing Auth ceremony session"
    end

    sessions.all? do |session|
      session.expires_at <= cutoff &&
        %i(revoked_at completed_at cancelled_at).all? do |column|
          timestamp = session.public_send(column)
          timestamp.nil? || timestamp <= cutoff
        end
    end
  end

  def validate_retention_period!
    value = retention_period.respond_to?(:value) ? retention_period.value : retention_period.to_f
    raise ArgumentError, "retention period must be finite and positive" unless value.finite? && value.positive?
  end
end
