# typed: false
# frozen_string_literal: true

module WithdrawalCeremonyAuthentication
  extend ActiveSupport::Concern
  include WithdrawalCeremonyCookie

  private

  def issue_withdrawal_ceremony!(subject:, purpose: "status")
    ceremony = withdrawal_ceremony_class.issue!(subject: subject, purpose: purpose, request: request)
    write_withdrawal_ceremony_cookie!(ceremony)
    @current_withdrawal_ceremony = ceremony
    @current_withdrawal_subject = subject
    record_withdrawal_ceremony_occurrence!("withdrawal.ceremony_issued", subject, ceremony)
    ceremony
  end

  def current_withdrawal_ceremony
    return @current_withdrawal_ceremony if defined?(@current_withdrawal_ceremony)

    public_id, token = read_withdrawal_ceremony_cookie
    @current_withdrawal_ceremony = withdrawal_ceremony_class.authenticate(public_id: public_id, token: token)
  end

  def current_withdrawal_subject
    return @current_withdrawal_subject if defined?(@current_withdrawal_subject)

    @current_withdrawal_subject = current_withdrawal_ceremony&.subject
  end

  def withdrawal_ceremony_required!
    return if current_withdrawal_subject.present?

    clear_withdrawal_ceremony_cookie!
    safe_redirect_to(withdrawal_ceremony_entry_path, fallback: withdrawal_public_fallback_path, status: :see_other)
  end

  # A status/re-entry proof is intentionally not an authorization for irreversible operations.
  # The purpose-specific issuance and assurance contract for termination is still pending, so
  # fail closed until a ceremony with the explicit termination purpose exists.
  def withdrawal_termination_ceremony_required!
    ceremony = current_withdrawal_ceremony
    return if ceremony&.purpose == "termination"

    raise Sign::InvalidWithdrawalStateError, ceremony&.purpose.presence || "missing"
  end

  def revoke_current_withdrawal_ceremony!
    ceremony = current_withdrawal_ceremony
    if ceremony&.active?
      ceremony.revoke!
      record_withdrawal_ceremony_occurrence!("withdrawal.ceremony_revoked", ceremony.subject, ceremony)
    end
    clear_withdrawal_ceremony_cookie!
    @current_withdrawal_ceremony = nil
    @current_withdrawal_subject = nil
  end

  def consume_current_withdrawal_ceremony!
    ceremony = current_withdrawal_ceremony
    if ceremony&.active?
      ceremony.consume!
      record_withdrawal_ceremony_occurrence!("withdrawal.ceremony_consumed", ceremony.subject, ceremony)
    end
    clear_withdrawal_ceremony_cookie!
    @current_withdrawal_ceremony = nil
    @current_withdrawal_subject = nil
  end

  def record_withdrawal_ceremony_occurrence!(event_type, subject, ceremony)
    WithdrawalOccurrenceRecording.record!(
      subject: subject,
      event_type: event_type,
      request: request,
      context: { ceremony_public_id: ceremony.public_id },
    )
  end

  def withdrawal_ceremony_entry_path
    return withdrawal_session_new_path if respond_to?(:withdrawal_session_new_path, true)

    withdrawal_new_path
  end
end
