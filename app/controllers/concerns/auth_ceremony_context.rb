# typed: false
# frozen_string_literal: true

# Reads the short-lived Auth-local continuity record. The browser cookie is only
# a lookup key; this concern never treats the record as identity, session, AAL,
# policy, or RP authority.
module AuthCeremonyContext
  extend ActiveSupport::Concern

  include AuthCeremonySidCookie

  private

  def require_sign_in_ceremony_admission!
    return render_sign_in_unavailable_while_authenticated if logged_in?
    return if auth_ceremony_matches_intent?("sign_in")

    refuse_sign_in_path!("ownership_mismatch")
  end

  def require_sign_up_ceremony_admission!
    return if auth_ceremony_matches_intent?("sign_up")

    refuse_sign_in_path!("ownership_mismatch")
  end

  def auth_social_admission_binding!
    record = admitted_auth_ceremony_session
    unless record&.active? && record.admission_purpose == "authentication_handoff"
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
    end

    binding = BaseAuthAdmissionCoordinator.admission_binding_model(auth_ceremony_surface)
      .find_by!(admitted_auth_ceremony_session_id: record.id)
    # F5 (WU-06): the 60-second acceptance expiry bounded only the redemption; after it, the
    # attempt's curfew (AuthAdmissionCurfewGate) is the limit.
    unless binding.redeemed? && !binding.retired? && AdmissionCurfewValue.for(binding).within? &&
        (auth_ceremony_matches_intent?("sign_in") || auth_ceremony_matches_intent?("sign_up"))
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
    end

    binding
  rescue ActiveRecord::RecordNotFound
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
  end

  def auth_sign_up_admission_binding!
    unless auth_ceremony_matches_intent?("sign_up")
      raise SignUpCycleLocator::OwnershipMismatch, "sign-up admission ownership mismatch"
    end

    model = BaseAuthAdmissionCoordinator.admission_binding_model(auth_ceremony_surface)
    model.connection_owner.connected_to(role: :writing) do
      model.find_by!(admitted_auth_ceremony_session_id: admitted_auth_ceremony_session.id)
    end
  rescue ActiveRecord::RecordNotFound
    raise SignUpCycleLocator::OwnershipMismatch, "sign-up admission ownership mismatch"
  end

  def render_sign_up_ownership_mismatch
    refuse_sign_in_path!("ownership_mismatch")
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
    return false if transaction.nil?

    record = admitted_auth_ceremony_session
    return false unless record

    binding = BaseAuthAdmissionCoordinator.admission_binding_model(auth_ceremony_surface)
      .find_by(admitted_auth_ceremony_session_id: record.id)
    return false unless binding&.purpose == "authentication_handoff" &&
      binding.authorization_transaction_id == transaction.id

    AuthEntryIntentResolver.call(
      prompt: transaction.oidc_prompt,
      entry_intent: binding.entry_intent,
    ) == expected_intent.to_s
  end
end
