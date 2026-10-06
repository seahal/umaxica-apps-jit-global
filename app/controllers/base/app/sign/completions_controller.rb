# frozen_string_literal: true

module Base
  module App
    module Sign
      class CompletionsController < ::Base::App::AuthorityController
        include BaseLocalAuthenticationCompletion

        AUTHENTICATION_MODE = :open
        # The first root login has no Browser-RP credential yet. The signed, one-shot Auth result,
        # Base browser locator, and normal CSRF/origin checks are the admission boundary here.
        skip_before_action :authenticate_browser_rp_unsafe_request!, raise: false

        declare_authentication_mode! :open

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
          authorize!(flow, to: :issue_session?, context: { user: actor })
        end

        def local_login_pending_response
          redirect_to(base_app_sign_in_limitation_path(ri: params[:ri]), status: :see_other)
        end
      end
    end
  end
end
