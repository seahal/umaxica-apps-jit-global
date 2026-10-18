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
          cycle = current_db_sign_in_flow_for_sequence
          return reject_oidc_result_handoff! unless cycle && oidc_result_handoff_cycle_ready?(cycle)

          authorize!(current_operator, to: :show?)
        end

        def oidc_result_handoff_surface = "org"

        def oidc_result_handoff_create_path(**) = auth_org_sign_oidc_handoff_path(**)

        def oidc_result_base_completion_url(**) = base_org_oauth_authorization_url(**)
      end
    end
  end
end
