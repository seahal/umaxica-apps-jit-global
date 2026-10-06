# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Guard
          class BaseController < ::Auth::App::ApplicationController
            include SignUpExplicitStepControllerSupport

            AUTHENTICATION_MODE = :open

            def show
              gate = SignUpStepGate.for_entry(
                controller: self,
                surface: sign_up_surface,
                family: sign_up_family,
                step: first_step,
              )
              return redirect_to(sign_up_restart_path) unless gate.success?

              @sign_up_ticket = gate.ticket
              return redirect_to(sign_up_restart_path) unless gate.current_step

              redirect_to(explicit_step_path(gate.current_step))
            end

            private

            def sign_up_surface = :app

            def sign_up_ticket_class = ClientSignUpFlow

            def sign_up_sequence_session_key = :auth_app_up_sequence_id

            def first_step
              SignUpRequirementRegistry.for_entry(
                surface: sign_up_surface,
                entry_method: sign_up_family,
              ).requirements.first
            end

            def explicit_step_path(step)
              helper = SignUpStepGate::STEP_ROUTES.fetch(sign_up_surface).fetch(sign_up_family).fetch(step)
              public_send(helper, **sign_up_flow_binding_params, ri: params[:ri], pt: signed_pt_param)
            end
          end
        end
      end
    end
  end
end
