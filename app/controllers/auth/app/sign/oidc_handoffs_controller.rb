# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class OidcHandoffsController < ::Auth::App::ApplicationController
        include ::AuthOidcResultHandoff

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        prepend_before_action :authenticate_oidc_result_actor!
        before_action :authorize_oidc_result_handoff!
        ensure_fqdn_gate_first!
        # Restores the inherited default no-store ahead of the gate (DefaultNoStore).
        prepend_before_action :apply_default_no_store

        private

        def sign_in_sequence_surface = :app

        def authorize_oidc_result_handoff!
          cycle = current_db_sign_in_flow_for_sequence
          return reject_oidc_result_handoff! unless cycle && oidc_result_handoff_cycle_ready?(cycle)

          authorize!(current_client, to: :show?)
        end

        def oidc_result_handoff_surface = "app"

        def oidc_result_handoff_create_helper = :auth_app_sign_oidc_handoff_path

        def oidc_result_base_completion_helper = :base_app_oauth_authorization_url
      end
    end
  end
end
