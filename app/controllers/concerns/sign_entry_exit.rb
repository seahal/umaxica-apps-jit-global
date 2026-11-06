# typed: false
# frozen_string_literal: true

# D05/D06/D09: the RP-facing Cancel and the Sign In/Up Switch. Cancel remains available for the
# current admitted ceremony while its parent OIDC authorization is unfinalized; Switch is limited
# to the first Sign In or Sign Up page. A clean entry-page reload after progress is refused.
#
# The including controller defines:
# - sign_entry_exit_sign_up_cycle_class: the surface sign-up cycle model, e.g. ClientSignUpFlow, or
#   nil on Org, which has no public Sign Up
# - sign_entry_exit_cancellation_path and sign_entry_exit_switch_path: this surface's POST endpoints
module SignEntryExit
  include AuthCeremonySidCookie
  include AuthCeremonyContext
  include StepUpCeremonyLogging

  private

  # The ceremony is still on its first page while it is admitted for a parent authorization, is not
  # terminal, has recorded no authentication evidence, has sent no email OTP and has started no
  # sign-up cycle. Anything else is progress, and Switch is refused.
  def sign_entry_first_page_ceremony(record: admitted_auth_ceremony_session)
    return nil unless record && !record.terminal? && record.admission_purpose == "authentication_handoff"
    return nil if sign_entry_ceremony_progressed?(record)

    cycle_class = sign_entry_exit_sign_up_cycle_class
    return record if cycle_class.nil?

    # E1 (WU-24h): a started sign-up is a Flow bound to this admission's Binding, whatever the locator says.
    binding = BaseAuthAdmissionCoordinator.admission_binding_model(auth_ceremony_surface)
      .find_by(admitted_auth_ceremony_session_id: record.id)
    return nil if binding && cycle_class.exists?(auth_admission_binding_id: binding.id)

    record
  end

  def refuse_progressed_sign_entry_page!(expected_intent:)
    record = admitted_auth_ceremony_session
    return false unless record&.admission_purpose == "authentication_handoff"
    return false unless auth_ceremony_handoff_intent(record) == expected_intent.to_s
    return false if sign_entry_first_page_ceremony(record: record)

    refuse_sign_entry_exit!("not_on_first_page")
    true
  end

  # Authentication evidence ends the first page everywhere; App also records a sent email OTP
  # on the ceremony, while Org sign-in has no email OTP step and no such column.
  def sign_entry_ceremony_progressed?(record)
    return true if record.authentication_evidence_recorded?

    case record
    when ClientAuthCeremonySession then record.email_otp_context.present?
    when OperatorAuthCeremonySession then false
    else raise ArgumentError, "unsupported Auth ceremony session: #{record.class.name}"
    end
  end

  def sign_entry_parent_transaction
    transaction = auth_ceremony_authorization_transaction
    transaction if transaction&.pending?
  end

  # Parent Cancel remains available after authentication progress until Base finalizes the
  # authorization. Switch is intentionally narrower and continues to use the first-page check.
  def sign_entry_parent_cancellation
    ceremony = admitted_auth_ceremony_session
    ceremony_class = BaseAuthAdmissionCoordinator.ceremony_session_class(auth_ceremony_surface)
    ceremony ||= ceremony_class.find_cancelled_parent_cancel_replay_by_raw_sid(read_auth_ceremony_sid_cookie)
    return unless ceremony && (ceremony.cancelled? || ceremony.active?) &&
      ceremony.admission_purpose == "authentication_handoff"

    transaction = auth_ceremony_authorization_transaction(ceremony)
    return unless transaction&.cancellation_handoff_available?

    [ceremony, transaction]
  end

  def commit_sign_entry_parent_cancellation!(ceremony:, transaction:)
    issuance = nil
    ceremony.class.connection_owner.connected_to(role: :writing) do
      ceremony.class.connection_owner.transaction do
        issuance = BaseAuthAdmissionCoordinator.issue_cancellation!(
          transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
        )
        ceremony.cancel! unless ceremony.cancelled?
      end
    end
    issuance
  end

  def redirect_to_sign_entry_parent_cancellation!(ceremony:, transaction:)
    issuance = commit_sign_entry_parent_cancellation!(ceremony:, transaction:)
    delete_auth_ceremony_sid_cookie!
    reset_session
    redirect_to_jump_url(
      visa_app_oidc_cancellation_url(
        cancellation_ref: issuance.reference, transaction_ref: transaction.transaction_id, ri: params[:ri],
        host: visa_authority_host, protocol: "https",
      ), status: :see_other,
    )
  end

  # True when this page belongs to an OIDC parent. Such a page must not offer the plain
  # Auth-to-Auth link to the other flow (D06); only the Switch form may move between them.
  def sign_entry_parent_bound?
    admitted_auth_ceremony_session&.admission_purpose == "authentication_handoff"
  end

  # Props for the first-page Cancel and Switch forms; each is nil when it is not available here.
  # switch_to is nil where the page offers no Switch (Org Sign In).
  def sign_entry_exit_forms(switch_to:, switch_label:)
    ceremony = sign_entry_first_page_ceremony
    transaction = ceremony && sign_entry_parent_transaction
    return { cancel_form: nil, switch_form: nil } unless transaction

    cancel_form = sign_entry_exit_form(t("actions.cancel"), sign_entry_exit_cancellation_path)
    switch_form =
      if switch_to && sign_entry_switch_allowed?(transaction, switch_to)
        sign_entry_exit_form(switch_label, sign_entry_exit_switch_path, to: switch_to)
      end
    { cancel_form:, switch_form: }
  end

  def sign_entry_switch_allowed?(transaction, target)
    BaseAuthAdmissionCoordinator.validate_switch_request!(transaction:, target:)
    true
  rescue BaseAuthAdmissionCoordinator::Denied
    false
  end

  def sign_entry_exit_form(label, action, to: nil)
    { label: label, action: action, to: to, authenticity_token: form_authenticity_token }
  end

  def refuse_sign_entry_exit!(reason)
    refusal_reason = (reason.to_s == "not_on_first_page") ? "not_on_first_page" : "exit_unavailable"
    render_sign_in_phase_refusal!(reason_code: refusal_reason)
  end
end
