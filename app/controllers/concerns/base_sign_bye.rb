# typed: false
# frozen_string_literal: true

# Base GET/POST /sign/bye (R5-WU16, one.md section 7.6).
#
# GET only reads the committed OP logout outcome bound to this browser; it never changes state.
# POST (CSRF-protected) consumes the browser-bound one-time LogoutReceipt and shows completion.
# Completion states that OP logout is established even while RP back-channel delivery or cookie
# purges are still pending: those are separate outcomes, never a condition of the logout.
module BaseSignBye
  extend ActiveSupport::Concern

  FLOWS = { "app" => [OpAppLogoutFlow, OpAppLogoutReceipt, OpAppLogoutFlowParticipant],
            "com" => [OpComLogoutFlow, OpComLogoutReceipt, OpComLogoutFlowParticipant],
            "org" => [OpOrgLogoutFlow, OpOrgLogoutReceipt, OpOrgLogoutFlowParticipant], }.freeze

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
    own_realm_receipt?(stored) ? bye_outcome_for(stored) : nil
  end

  def own_realm_receipt?(stored)
    stored.is_a?(Hash) && stored["realm"] == self.class.base_admission_surface_name
  end

  def bye_outcome_for(stored)
    flow_class, _, participant_class = FLOWS.fetch(self.class.base_admission_surface_name)
    flow = flow_class.find_by!(public_id: stored.fetch("flow"))
    participants = participant_class.where(logout_flow_id: flow.id)
    {
      op_logout_established: flow.op_revoked_at.present?,
      rp_notifications_pending: participants.where(completed_at: nil).count,
      rp_notifications_completed: participants.where.not(completed_at: nil).count,
    }
  end

  def consume_bye_receipt!(stored)
    flow_class, receipt_class, = FLOWS.fetch(self.class.base_admission_surface_name)
    receipt_class.transaction do
      flow = flow_class.find_by(public_id: stored.fetch("flow"))
      receipt = flow && receipt_class.lock.find_by(
        logout_flow_id: flow.id, nonce_digest: Digest::SHA256.digest(stored.fetch("nonce").to_s),
      )
      now = receipt_class.database_now
      next false unless receipt && receipt.consumed_at.nil? && receipt.expires_at > now

      receipt.update!(consumed_at: now)
      true
    end
  end
end
