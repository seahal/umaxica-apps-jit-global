# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      class OidcHandoffsController < ::Auth::Com::ApplicationController
        include ::AuthOidcResultHandoff

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        prepend_before_action :authenticate_oidc_result_actor!
        before_action :authorize_oidc_result_handoff!
        ensure_fqdn_gate_first!

        private

        def sign_in_sequence_surface = :com

        def authorize_oidc_result_handoff!
          return reject_oidc_result_handoff! unless current_db_sign_in_flow_for_sequence&.sign_in_dashboard_pending?

          authorize!(current_visitor, to: :show?)
        end

        def oidc_result_handoff_surface = "com"

        def oidc_result_handoff_create_helper = :auth_com_sign_oidc_handoff_path

        def oidc_result_base_completion_helper = :base_com_oauth_authorization_url
      end
    end
  end
end
