# typed: false
# frozen_string_literal: true

class Auth::App::Edge::V0::Token::DbscController < ::Auth::App::ApplicationController
  include SignEdgeV0JsonApi

  include SignDbscRegistrationEndpoint

  # D-59: DBSC registration is not a browser Sign Entry.
  sign_entry_classification! :excluded, reason: "edge token endpoint, not a sign entry"

  AUTHENTICATION_MODE = :deny_all

  declare_authentication_mode! :open
  before_action :ensure_json_request
  skip_before_action :set_region, raise: false
  skip_before_action :set_preferences_cookie
  skip_before_action :transparent_refresh_access_token

  private

  def dbsc_url
    auth_app_edge_v0_token_dbsc_url
  end
end
