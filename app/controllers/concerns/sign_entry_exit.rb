# typed: false
# frozen_string_literal: true

# D05/D06/D09: the RP-facing Cancel and the Sign In/Up Switch. Both exist only on the first Sign In
# or Sign Up page of an Auth ceremony admitted for a parent OIDC authorization transaction. After
# that page, the in-Auth step cancellation (restart within Auth) is the only cancellation.
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
  # sign-up cycle. Anything else is progress, and Cancel/Switch are refused.
  def sign_entry_first_page_ceremony
    record = admitted_auth_ceremony_session
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

  # Authentication evidence ends the first page everywhere; App and Com also record a sent email OTP
  # on the ceremony, while Org sign-in has no email OTP step and no such column.
  def sign_entry_ceremony_progressed?(record)
    return true if record.authentication_evidence_recorded?

    case record
    when ClientAuthCeremonySession, VisitorAuthCeremonySession then record.email_otp_context.present?
    when OperatorAuthCeremonySession then false
    else raise ArgumentError, "unsupported Auth ceremony session: #{record.class.name}"
    end
  end

  def sign_entry_parent_transaction
    transaction = auth_ceremony_authorization_transaction
    transaction if transaction && transaction.status == OidcAuthorizationTransactionable::STATUS_PENDING
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
    Rails.logger.warn(
      JitLogEvent.format(
        "auth.sign_entry_exit.refused", surface: auth_ceremony_surface, action: controller_name, reason: reason,
                                        request_id: request.request_id,
      ),
    )
    render plain: I18n.t("errors.messages.invalid_request"), status: :unprocessable_content
  end
end
