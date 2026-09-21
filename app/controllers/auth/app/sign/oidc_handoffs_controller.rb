# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class OidcHandoffsController < ::Auth::App::ApplicationController
        include ::AuthOidcResultHandoff

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        before_action :authenticate_client!
        before_action :authorize_oidc_result_handoff!

        private

        def authorize_oidc_result_handoff!
          authorize!(current_client, to: :show?)
        end

        def oidc_result_handoff_surface = "app"

        def oidc_result_handoff_create_helper = :auth_app_sign_oidc_handoff_path

        def oidc_result_base_completion_helper = :base_app_oauth_authorization_url
      end
    end
  end
end
