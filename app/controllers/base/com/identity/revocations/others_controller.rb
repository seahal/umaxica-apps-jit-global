# typed: false
# frozen_string_literal: true

class Base::Com::Identity::Revocations::OthersController < ::Base::Com::ApplicationController
  AUTHENTICATION_MODE = :private

  step_up only: %i(create destroy), scope: "session_revoke_all"

  def create
    authorize!(VisitorToken, to: :revoke_others?)
    AuthenticationOtherSessionsRevoker.call(
      owner: current_visitor,
      sessions: current_visitor.visitor_tokens.session_inventory,
      current_token: current_session,
      current_session_public_id: current_session_public_id,
      step_up_requirement: step_up_requirement(scope: "session_revoke_all"),
    )
    redirect_to(base_com_sessions_path(ri: params[:ri]), status: :see_other)
  rescue AuthenticationOtherSessionsRevoker::StepUpUnavailable
    require_step_up!(scope: "session_revoke_all")
  end
  alias_method :destroy, :create
end
