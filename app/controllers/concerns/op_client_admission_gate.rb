# typed: false
# frozen_string_literal: true

# OP-side admission check at the authorization and token endpoints (R5-WU19). Enforced in a Base OP
# role process: a client without an enabled activation for the current contract epoch gets no Code
# and no token. The shared transitional role (pre-cutover topology) does not consult admission;
# RuntimeRole::SHARED records that exit condition.
module OpClientAdmissionGate
  extend ActiveSupport::Concern

  private

  def op_client_admitted?(client_id)
    return true unless RuntimeRole::OP_ROLES.include?(RuntimeRole.current)

    OpClientAdmissionQuery.admitted?(client_id:)
  end

  def render_client_not_admitted
    render json: { error: "unauthorized_client", error_description: "client is not admitted" }, status: :bad_request
  end
end
