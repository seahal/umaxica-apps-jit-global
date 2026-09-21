# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      class OidcHandoffsController < ::Auth::Org::ApplicationController
        include ::AuthOidcResultHandoff

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        before_action :authenticate_operator!
        before_action :authorize_oidc_result_handoff!

        private

        def authorize_oidc_result_handoff!
          authorize!(current_operator, to: :show?)
        end

        def oidc_result_handoff_surface = "org"

        def oidc_result_handoff_create_helper = :auth_org_sign_oidc_handoff_path

        def oidc_result_base_completion_helper = :base_org_oauth_authorization_url
      end
    end
  end
end
