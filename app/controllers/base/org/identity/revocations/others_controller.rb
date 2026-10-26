# typed: false
# frozen_string_literal: true

class Base::Org::Identity::Revocations::OthersController < ::Base::Org::ApplicationController
  AUTHENTICATION_MODE = :private

  step_up only: %i(create destroy), scope: "session_revoke_all"

  def create
    authorize!(OperatorToken, to: :revoke_others?)
    AuthenticationOtherSessionsRevoker.call(
      owner: current_operator,
      sessions: current_operator.staff_tokens.session_inventory,
      current_token: current_session,
      current_session_public_id: current_session_public_id,
      step_up_requirement: step_up_requirement(scope: "session_revoke_all"),
    )
    redirect_to(base_org_sessions_path(ri: params[:ri]), status: :see_other)
  rescue AuthenticationOtherSessionsRevoker::StepUpUnavailable
    require_step_up!(scope: "session_revoke_all")
  end
  alias_method :destroy, :create
end
