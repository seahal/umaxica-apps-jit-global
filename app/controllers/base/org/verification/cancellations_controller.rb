# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Verification
      class CancellationsController < Base::Org::ApplicationController
        include BaseStepUpCancellation

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!

        def create
          authorize!(current_operator, to: :show?)
          cancel_step_up_ceremony!(
            surface: "org",
            actor: current_operator,
            token: current_session_token,
            destination: base_org_dashboard_path(ri: params[:ri]),
          )
        end

        private

        def cancellation_step_up_transaction(reference)
          OperatorStepUpCeremonyTransaction.connection_owner.connected_to(role: :writing) do
            OperatorStepUpCeremonyTransaction.find_by!(transaction_id: reference)
          end
        end

        def actor_verification_path(**args)
          base_org_verification_path(**args)
        end
      end
    end
  end
end
