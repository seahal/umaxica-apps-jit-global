# typed: false
# frozen_string_literal: true

class Base::Com::Identity::Revocations::OthersController < ::Base::Com::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_visitor!

  def create
    authorize!(VisitorToken, to: :revoke_others?)
    AuthenticationOtherSessionsRevoker.call(
      owner: current_visitor,
      sessions: current_visitor.visitor_tokens.session_inventory,
      current_token: current_session,
      current_session_public_id: current_session_public_id,
    )
    redirect_to(base_com_sessions_path(ri: params[:ri]), status: :see_other)
  end
  alias_method :destroy, :create
end
