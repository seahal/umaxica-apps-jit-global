# typed: false
# frozen_string_literal: true

class Base::Org::Identity::Revocations::OthersController < ::Base::Org::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_operator!

  def create
    authorize!(OperatorToken, to: :revoke_others?)
    AuthenticationOtherSessionsRevoker.call(
      owner: current_operator,
      sessions: current_operator.staff_tokens.session_inventory,
      current_token: current_session,
      current_session_public_id: current_session_public_id,
    )
    redirect_to(base_org_sessions_path(ri: params[:ri]), status: :see_other)
  end
  alias_method :destroy, :create
end
