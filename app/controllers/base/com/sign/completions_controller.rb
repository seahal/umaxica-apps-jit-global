# frozen_string_literal: true

module Base
  module Com
    module Sign
      class CompletionsController < ::Base::Com::AuthorityController
        include BaseLocalAuthenticationCompletion

        AUTHENTICATION_MODE = :open
        skip_before_action :authenticate_browser_rp_unsafe_request!, raise: false

        declare_authentication_mode! :open

        private

        def local_login_surface = "com"

        def local_login_success_path = base_com_dashboard_path(ri: params[:ri])

        def local_login_flow(public_id)
          ComTicketRecord.connected_to(role: :writing) { VisitorSignInFlow.find_by!(public_id: public_id) }
        end

        def local_login_actor(flow)
          Visitor.connection_class_for_self.connected_to(role: :writing) { Visitor.find(flow.principal_id) }
        end

        def authorize_local_login!(flow, actor)
          authorize!(flow, to: :issue_session?, context: { user: actor })
        end

        def local_login_pending_response
          redirect_to(base_com_sign_in_limitation_path(ri: params[:ri]), status: :see_other)
        end
      end
    end
  end
end
