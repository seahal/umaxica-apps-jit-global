# frozen_string_literal: true

module Auth
  module App
    module Sign
      class HandoffsController < ::Auth::App::ApplicationController
        include AuthLocalResultHandoff

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        prepend_before_action :authenticate_sign_in_sequence_actor!
        before_action :authorize_local_result!
        ensure_fqdn_gate_first!
        prepend_before_action :apply_default_no_store

        private

        def authorize_local_result!
          flow = auth_ceremony_local_sign_in_flow
          return reject_invalid_sign_in_sequence! unless flow&.sign_in_session_issuance_pending?

          authorize!(flow, to: :issue_session?)
        end

        def local_result_create_path = auth_app_sign_handoff_path(ri: params[:ri])

        def local_result_layout = "auth/app/application"

        def local_result_completion_url(**)
          base_app_sign_completion_url(**, host: base_authority_host, protocol: "https")
        end
      end
    end
  end
end
