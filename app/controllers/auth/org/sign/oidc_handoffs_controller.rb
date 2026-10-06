# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      class OidcHandoffsController < ::Auth::Org::ApplicationController
        include ::AuthOidcResultHandoff

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        prepend_before_action :authenticate_oidc_result_actor!
        before_action :authorize_oidc_result_handoff!
        ensure_fqdn_gate_first!
        # Restores the inherited default no-store ahead of the gate (DefaultNoStore).
        prepend_before_action :apply_default_no_store

        private

        def sign_in_sequence_surface = :org

        def authorize_oidc_result_handoff!
          return reject_oidc_result_handoff! unless current_db_sign_in_flow_for_sequence&.sign_in_completed?

          authorize!(current_operator, to: :show?)
        end

        def oidc_result_handoff_surface = "org"

        def oidc_result_handoff_create_helper = :auth_org_sign_oidc_handoff_path

        def oidc_result_base_completion_helper = :base_org_oauth_authorization_url
      end
    end
  end
end
