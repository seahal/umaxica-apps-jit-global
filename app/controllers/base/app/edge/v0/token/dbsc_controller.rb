# typed: false
# frozen_string_literal: true

class Base::App::Edge::V0::Token::DbscController < Base::App::AuthorityController
  include SignEdgeV0JsonApi
  include SignDbscRegistrationEndpoint

  AUTHENTICATION_MODE = :deny_all

  declare_authentication_mode! :open
  before_action :ensure_json_request

  private

  def dbsc_url
    base_app_edge_v0_token_dbsc_url
  end
end
