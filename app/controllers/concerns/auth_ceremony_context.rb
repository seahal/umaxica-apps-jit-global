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

  def cancel_auth_ceremony_session!
    record = admitted_auth_ceremony_session
    return if record.nil?

    record.cancel!
  end

  def auth_ceremony_admission_present?
    admitted_auth_ceremony_session.present?
  end

  def auth_ceremony_matches_intent?(expected_intent)
    transaction = auth_ceremony_authorization_transaction
    return true if transaction.nil?

    transaction.intent.to_s == expected_intent.to_s ||
      (ORDINARY_AUTHENTICATION_INTENTS.include?(transaction.intent.to_s) &&
        %w(sign_in sign_up).include?(expected_intent.to_s))
  end
end
