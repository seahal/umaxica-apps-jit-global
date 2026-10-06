# typed: false
# frozen_string_literal: true

class Base::Org::Edge::V0::Token::ChecksController < Base::Org::AuthorityController
  include SignEdgeV0JsonApi

  AUTHENTICATION_MODE = :deny_all

  declare_authentication_mode! :open
  before_action :ensure_json_request

  def show
    response.set_header("Cache-Control", "no-store")

    authenticated = logged_in? && current_resource.active?
    issue_dbsc_registration_header_for(current_session) if authenticated
    body =
      if authenticated
        {
          authenticated: true,
          type: resource_type,
          id: current_resource.id,
          sid: current_session_public_id,
          dbsc: dbsc_payload_for(current_session),
        }
      else
        { authenticated: false }
      end

    render json: body, status: authenticated ? :ok : :unauthorized
  end
end
