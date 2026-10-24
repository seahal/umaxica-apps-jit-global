# typed: false
# frozen_string_literal: true

# WU-06 (REQ-CURFEW 3, D-160): every Auth request admitted on the Sign-in path is refused at or after
# the attempt's curfew. The admitted ceremony cookie proves the owner's own browser, so its attempt
# leaves through the Cancel exit and the RP receives access_denied with its unchanged state. Without
# the authorization transaction the uniform error answers and nothing else changes.
module AuthAdmissionCurfewGate
  private

  def enforce_admission_curfew!
    ceremony = admitted_auth_ceremony_session
    return unless ceremony&.admission_purpose == "authentication_handoff"

    binding_model = BaseAuthAdmissionCoordinator.admission_binding_model(auth_ceremony_surface)
    binding_model.connection_owner.connected_to(role: :writing) do
      binding_model.transaction do
        binding = binding_model.lock.find_by(admitted_auth_ceremony_session_id: ceremony.id)
        return if binding.nil? || binding.purpose != "authentication_handoff"
        return if AdmissionCurfewValue.for(binding).within?

        exit_attempt_after_curfew!(ceremony)
      end
    end
  end

  def exit_attempt_after_curfew!(ceremony)
    transaction = auth_ceremony_authorization_transaction
    return render_curfew_uniform_refusal unless transaction

    record_sign_in_path_refusal!("curfew_passed")
    issuance = BaseAuthAdmissionCoordinator.issue_cancellation!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    ceremony.cancel!
    redirect_to_jump_url(
      curfew_exit_url(cancellation_ref: issuance.reference, transaction_ref: transaction.transaction_id),
      status: :see_other,
    )
  rescue BaseAuthAdmissionCoordinator::Denied, AuthCeremonySession::InvalidTransition, ArgumentError
    render_curfew_uniform_refusal
  end

  def render_curfew_uniform_refusal
    refuse_sign_in_path!("transaction_missing")
  end
end
