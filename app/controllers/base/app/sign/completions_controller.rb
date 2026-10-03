# frozen_string_literal: true

module Base
  module App
    module Sign
      class CompletionsController < ::Base::App::ApplicationController
        include BaseLocalAuthenticationCompletion

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        LOCAL_RESULT_ORIGINS = JitHostOriginEnv.trusted_origins(ENV.fetch("PUBLIC_AUTH_SERVICE_URL")).freeze
        protect_from_forgery using: :header_or_legacy_token, trusted_origins: LOCAL_RESULT_ORIGINS, with: :exception

        private

        def local_login_surface = "app"

        def local_login_success_path = base_app_dashboard_path(ri: params[:ri])

        def local_login_flow(public_id)
          AppTicketRecord.connected_to(role: :writing) { ClientSignInFlow.find_by!(public_id: public_id) }
        end

        def local_login_actor(flow)
          Client.connection_class_for_self.connected_to(role: :writing) { Client.find(flow.principal_id) }
        end

        def authorize_local_login!(flow, actor)
          if flow.sign_in_session_limit_pending?
            authorize!(flow, to: :manage_session_limit?, context: { user: actor })
          else
            authorize!(flow, to: :issue_session?, context: { user: actor })
          end
        end

        def local_login_pending_response
          redirect_to(base_app_sign_in_limitation_path(ri: params[:ri]), status: :see_other)
        end
      end
    end
  end
end
