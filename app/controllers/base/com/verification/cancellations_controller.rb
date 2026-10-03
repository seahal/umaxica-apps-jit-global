# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Verification
      class CancellationsController < Base::Com::ApplicationController
        include BaseStepUpCancellation

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!

        def create
          authorize!(current_visitor, to: :show?)
          cancel_step_up_ceremony!(
            surface: "com",
            actor: current_visitor,
            token: current_session_token,
            destination: base_com_dashboard_path(ri: params[:ri]),
          )
        end

        private

        def cancellation_step_up_transaction(reference)
          VisitorStepUpCeremonyTransaction.connection_owner.connected_to(role: :writing) do
            VisitorStepUpCeremonyTransaction.find_by!(transaction_id: reference)
          end
        end

        def actor_verification_path(**args)
          base_com_verification_path(**args)
        end
      end
    end
  end
end
