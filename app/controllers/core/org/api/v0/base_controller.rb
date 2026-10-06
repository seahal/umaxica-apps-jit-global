# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Api
      module V0
        # This API base is self-contained because the Core browser API must not
        # inherit HTML callbacks that write unrelated cookies.
        class BaseController < ActionController::Base # rubocop:disable Rails/ApplicationController
          include ActionPolicy::Controller
          include ::CoreBrowserApiBoundary

          AUTHENTICATION_MODE = :bare

          protect_from_forgery using: :header_or_legacy_token, with: :exception

          authorize :user, through: :current_policy_user
          authorize :actor, through: :current_actor

          rescue_from ActionController::InvalidCrossOriginRequest, with: :render_csrf_failure
          rescue_from ActionPolicy::Unauthorized, with: :render_authorization_denied

          before_action :require_core_browser_api_enabled!
          before_action :verify_core_browser_api_csrf!

          private

          def core_actor_tld = :org

          def core_resource_class = ::Operator

          def core_token_class = ::OperatorToken

          def core_resource_type = "operator"
        end
      end
    end
  end
end
