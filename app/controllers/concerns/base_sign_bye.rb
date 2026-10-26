# typed: false
# frozen_string_literal: true

# Base GET/POST /sign/bye (R5-WU16, one.md section 7.6).
#
# GET only reads the committed OP logout outcome bound to this browser; it never changes state.
# POST (CSRF-protected) consumes the browser-bound one-time receipt of the authority stop and shows
# completion.
# Completion states that OP logout is established even while RP back-channel delivery or cookie
# purges are still pending: those are separate outcomes, never a condition of the logout.
module BaseSignBye
  extend ActiveSupport::Concern

  STOPS = { "app" => [OpAppAuthorityStop, OpAppAuthorityStopBrowserLogout, OpAppAuthorityStopParticipant],
            "com" => [OpComAuthorityStop, OpComAuthorityStopBrowserLogout, OpComAuthorityStopParticipant],
            "org" => [OpOrgAuthorityStop, OpOrgAuthorityStopBrowserLogout, OpOrgAuthorityStopParticipant], }.freeze

  public

  def show
    response.set_header("Cache-Control", "no-store")
    outcome = bye_outcome
    return head(:not_found) unless outcome

    render json: outcome
  end

  def create
    response.set_header("Cache-Control", "no-store")
    stored = session[OpLogoutReceiptSession::KEY]
    return head(:not_found) unless own_realm_receipt?(stored) && consume_bye_receipt!(stored)

    session.delete(OpLogoutReceiptSession::KEY)
    render json: bye_outcome_for(stored).merge(receipt_consumed: true)
  end

  private

  def bye_outcome
    stored = session[OpLogoutReceiptSession::KEY]
    return unless own_realm_receipt?(stored) && valid_bye_receipt?(stored)

    bye_outcome_for(stored)
  end

  def own_realm_receipt?(stored)
    stored.is_a?(Hash) && stored["realm"] == self.class.base_admission_surface_name &&
      stored["stop"].is_a?(String) && stored["stop"].present? &&
      stored["nonce"].is_a?(String) && stored["nonce"].present? &&
      stored["browser_binding"].is_a?(String) && stored["browser_binding"].present?
  end

  def bye_outcome_for(stored)
    stop_class, _, participant_class = STOPS.fetch(self.class.base_admission_surface_name)
    stop = stop_class.find_by!(public_id: stored.fetch("stop"))
    participants = participant_class.where(stop_id: stop.id)
    final = OpAuthorityStopReference::FINAL_PARTICIPANT_STATUS_IDS
    {
      op_logout_established: true,
      rp_notifications_pending: participants.where.not(status_id: final).count,
      rp_notifications_completed: participants.where(status_id: final).count,
    }
  end

  def consume_bye_receipt!(stored)
    stop_class, browser_logout_class, = STOPS.fetch(self.class.base_admission_surface_name)
    browser_logout_class.transaction do
      stop = stop_class.find_by(public_id: stored.fetch("stop"))
      receipt = stop && browser_logout_class.lock.find_by(
        stop_id: stop.id, receipt_nonce_digest: Digest::SHA256.digest(stored.fetch("nonce").to_s),
      )
      now = browser_logout_class.database_now
      next false unless valid_receipt_record?(receipt, stored, now:)

      receipt.update!(receipt_consumed: true)
      true
    end
  end

  def valid_bye_receipt?(stored)
    stop_class, browser_logout_class, = STOPS.fetch(self.class.base_admission_surface_name)
    stop = stop_class.find_by(public_id: stored.fetch("stop"))
    receipt = stop && browser_logout_class.find_by(
      stop_id: stop.id, receipt_nonce_digest: Digest::SHA256.digest(stored.fetch("nonce")),
    )

    valid_receipt_record?(receipt, stored, now: browser_logout_class.database_now)
  end

  def valid_receipt_record?(receipt, stored, now:)
    return false unless receipt && !receipt.receipt_consumed && receipt.receipt_expires_at > now

    expected_binding = Digest::SHA256.digest(stored.fetch("browser_binding"))
    ActiveSupport::SecurityUtils.secure_compare(receipt.browser_binding_digest, expected_binding)
  end
end
