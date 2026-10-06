# frozen_string_literal: true

module Base
  module Org
    module Sign
      class CompletionsController < ::Base::Org::AuthorityController
        include BaseLocalAuthenticationCompletion

        AUTHENTICATION_MODE = :open
        skip_before_action :authenticate_browser_rp_unsafe_request!, raise: false

        declare_authentication_mode! :open

        private

        def local_login_surface = "org"

        def local_login_success_path = base_org_dashboard_path(ri: params[:ri])

        def local_login_flow(public_id)
          OrgTicketRecord.connected_to(role: :writing) { OperatorSignInFlow.find_by!(public_id: public_id) }
        end

        def local_login_actor(flow)
          Operator.connection_class_for_self.connected_to(role: :writing) { Operator.find(flow.principal_id) }
        end

        def authorize_local_login!(flow, actor)
          authorize!(flow, to: :issue_session?, context: { user: actor })
        end

        def local_login_pending_response
          redirect_to(base_org_sign_in_limitation_path(ri: params[:ri]), status: :see_other)
        end
      end
    end
  end
end
