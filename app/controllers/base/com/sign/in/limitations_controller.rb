# frozen_string_literal: true

module Base
  module Com
    module Sign
      module In
        class LimitationsController < ::Base::Com::AuthorityController
          include ::SurfaceInertiaPage
          include ::BaseSignInLimitations

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :load_resolution

          private

          def actor_class = Visitor

          def token_class = VisitorToken

          def ticket_record = ComTicketRecord

          def resolution_transaction_class = VisitorSessionLimitResolutionTransaction

          def actor_foreign_key = :visitor_id

          def limitation_component = "base/com/sign/in/limitations/show"

          def limitation_path(params = {}) = base_com_sign_in_limitation_path(**params)

          def base_sign_entry_path(**params) = base_com_sign_show_path(**params)

          def local_login_success_path = base_com_dashboard_path(ri: params[:ri])
        end
      end
    end
  end
end
