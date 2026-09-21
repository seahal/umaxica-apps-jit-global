# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      class OidcHandoffsController < ::Auth::Com::ApplicationController
        include ::AuthOidcResultHandoff

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        before_action :authenticate_visitor!
        before_action :authorize_oidc_result_handoff!

        private

        def authorize_oidc_result_handoff!
          authorize!(current_visitor, to: :show?)
        end

        def oidc_result_handoff_surface = "com"

        def oidc_result_handoff_create_helper = :auth_com_sign_oidc_handoff_path

        def oidc_result_base_completion_helper = :base_com_oauth_authorization_url
      end
    end
  end
end
