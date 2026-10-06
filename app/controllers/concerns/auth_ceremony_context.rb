# typed: false
# frozen_string_literal: true

# Reads the short-lived Auth-local continuity record. The browser cookie is only
# a lookup key; this concern never treats the record as identity, session, AAL,
# policy, or RP authority.
module AuthCeremonyContext
  extend ActiveSupport::Concern

  include AuthCeremonySidCookie

  ORDINARY_AUTHENTICATION_INTENTS = %w(authentication sign_in sign_up).freeze

  private

  def require_sign_in_ceremony_admission!
    return render_sign_in_unavailable_while_authenticated if logged_in?
    return if auth_ceremony_matches_intent?("sign_in")

    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  def auth_ceremony_surface
    self.class.const_get(:AUTH_CEREMONY_SURFACE)
  end

  def current_auth_ceremony_session
    return nil unless respond_to?(:request) && request.present?

    raw_sid = read_auth_ceremony_sid_cookie
    return nil if raw_sid.blank?

    BaseAuthAdmissionCoordinator.ceremony_session_class(auth_ceremony_surface)
      .find_active_by_raw_sid(raw_sid)
  rescue ArgumentError, ActiveRecord::RecordNotFound
    nil
  end

  def admitted_auth_ceremony_session
    record = current_auth_ceremony_session
    record if record&.admitted?
  end

  def auth_ceremony_authorization_transaction
    record = admitted_auth_ceremony_session
    return nil unless record&.admission_purpose == "authentication_handoff"

    transaction_ref = record&.authorization_transaction_ref
    return nil if transaction_ref.blank?

    OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: auth_ceremony_surface,
      transaction_id: transaction_ref,
    )
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def oidc_authorization_login_challenge
    auth_ceremony_authorization_transaction&.login_challenge
  end

  def auth_ceremony_local_sign_in_flow
    record = admitted_auth_ceremony_session
    return nil unless record&.local_sign_in_flow_ref
    return nil unless %w(local_sign_in local_sign_up).include?(record.admission_purpose)

    model = BaseAuthAdmissionCoordinator::LOCAL_SIGN_IN_FLOW.fetch(auth_ceremony_surface)
    model.connection_class_for_self.connected_to(role: :writing) do
      flow = model.find_by!(public_id: record.local_sign_in_flow_ref)
      return nil if flow.expired?(model.database_now) || flow.sign_in_failed?

      flow
    end
  end

  def auth_ceremony_step_up_transaction
    auth_ceremony_ticket_transaction(%w(step_up reauthentication))
  end

  def auth_ceremony_registration_transaction
    auth_ceremony_ticket_transaction(%w(bootstrap credential_registration))
  end

  # Cancellation is the one Auth lookup that must also reach an already-canceled durable
  # transaction so a retried handoff can converge on Base's idempotent receiver. Admission and
  # verification lookups intentionally continue to accept only live transactions.
  def auth_cancellation_transaction
    record = admitted_auth_ceremony_session
    transaction_ref = record&.step_up_ceremony_transaction_ref
    return nil if transaction_ref.blank?

    purpose =
      case record.admission_purpose
      when "step_up_handoff" then "step_up"
      when "reauthentication_handoff" then "reauthentication"
      when "bootstrap_handoff" then "bootstrap"
      when "credential_registration_handoff" then "credential_registration"
      when "credential_change_handoff" then "credential_change"
      else return nil
      end

    model = BaseAuthAdmissionCoordinator::STEP_UP_TRANSACTION.fetch(auth_ceremony_surface)
    model.connection_owner.connected_to(role: :writing) do
      transaction = model.find_by(transaction_id: transaction_ref, surface: auth_ceremony_surface)
      return nil unless transaction && BaseAuthAdmissionCoordinator::TICKET_CEREMONY_PURPOSES.include?(purpose) &&
        transaction.purpose == purpose && transaction.status.in?(%w(pending verified canceled))

      transaction
    end
  rescue KeyError, ActiveRecord::RecordNotFound
    nil
  end

  def auth_ceremony_ticket_transaction(expected_purposes)
    record = admitted_auth_ceremony_session
    return nil if record&.step_up_ceremony_transaction_ref.blank?

    intent =
      case record.admission_purpose
      when "step_up_handoff" then "step_up"
      when "reauthentication_handoff" then "reauthentication"
      when "bootstrap_handoff" then "bootstrap"
      when "credential_registration_handoff" then "credential_registration"
      when "credential_change_handoff" then "credential_change"
      else return nil
      end
    return nil unless expected_purposes.include?(intent)

    BaseAuthAdmissionCoordinator.resolve_step_up_admission!(
      payload: {
        "purpose" => record.admission_purpose,
        "surface" => auth_ceremony_surface,
        "actor_type" => BaseAuthAdmissionCoordinator::SURFACE_ACTOR.fetch(auth_ceremony_surface),
        "subject_ref" => record.step_up_ceremony_transaction_ref,
      },
      surface: auth_ceremony_surface, expected_intent: intent,
    )
  rescue BaseAuthAdmissionCoordinator::Denied => e
    # Kept for the ceremony log of this request only; the response stays generic.
    @auth_ceremony_ticket_refusal = {
      error_code: e.code,
      ceremony_ref: StepUpObservabilityDigest.ceremony_ref(record.step_up_ceremony_transaction_ref),
    }
    nil
  end

  def auth_ceremony_ticket_refusal
    @auth_ceremony_ticket_refusal || { error_code: "invalid_admission" }
  end

  def complete_auth_ceremony_session!
    record = admitted_auth_ceremony_session
    return if record.nil?

    record.complete!
  end

  # Auth owns only ceremony continuity. Ending that continuity may revoke the
  # short-lived ceremony row and clear local browser state, but it must never
  # revoke a Base Browser Session or an RP Session.
  def clear_auth_ceremony_context!
    current_auth_ceremony_session&.revoke!
    cookies.delete(auth_ceremony_sid_cookie_name, path: "/")
    clear_auth_cookies! if respond_to?(:clear_auth_cookies!, true)
    reset_session
  end

  def auth_ceremony_admission_present?
    admitted_auth_ceremony_session.present?
  end

  def auth_ceremony_matches_intent?(expected_intent)
    if BaseAuthAdmissionCoordinator::TICKET_CEREMONY_PURPOSES.include?(expected_intent.to_s)
      return auth_ceremony_ticket_transaction([expected_intent.to_s])&.purpose == expected_intent.to_s
    end

    transaction = auth_ceremony_authorization_transaction
    if transaction.nil?
      expected_purpose = BaseAuthAdmissionCoordinator::LOCAL_ENTRY_PURPOSE[expected_intent.to_s]
      return expected_purpose.present? && admitted_auth_ceremony_session&.admission_purpose == expected_purpose &&
          auth_ceremony_local_sign_in_flow.present?
    end

    transaction.intent.to_s == expected_intent.to_s ||
      (ORDINARY_AUTHENTICATION_INTENTS.include?(transaction.intent.to_s) &&
        %w(sign_in sign_up).include?(expected_intent.to_s))
  end
end
