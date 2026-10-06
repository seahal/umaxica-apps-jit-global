# frozen_string_literal: true

module Base
  module Org
    module Sign
      module In
        class LimitationsController < ::Base::Org::AuthorityController
          include ::SurfaceInertiaPage
          include ::BaseSignInLimitations

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :load_resolution

          private

          def actor_class = Operator

          def token_class = OperatorToken

          def ticket_record = OrgTicketRecord

          def resolution_transaction_class = OperatorSessionLimitResolutionTransaction

          def actor_foreign_key = :staff_id

          def limitation_component = "base/org/sign/in/limitations/show"

          def limitation_path(params = {}) = base_org_sign_in_limitation_path(**params)

          def base_sign_entry_path(**params) = base_org_sign_show_path(**params)

          def local_login_success_path = base_org_dashboard_path(ri: params[:ri])
        end
      end
    end
  end
end
