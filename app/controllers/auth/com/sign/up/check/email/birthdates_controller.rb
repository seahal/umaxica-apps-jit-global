# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module Up
        module Check
          module Email
            class BirthdatesController < ::Auth::Com::ApplicationController
              include SignUpExplicitStepControllerSupport
              include ::ComSignUpCheckpointPage
              include ::SurfaceInertiaPage

              AUTHENTICATION_MODE = :guest

              def show
                return unless load_gate_context!(gate_for_show)

                render_sign_up_checkpoint
              end

              def update
                return unless load_gate_context!(gate_for_update)

                clear_sign_up_birthdate_requirement
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def sign_up_surface = :com

              def sign_up_ticket_class = VisitorSignUpFlow

              def sign_up_sequence_session_key = :auth_com_up_sequence_id

              def sign_up_family = "email"

              def sign_up_step = :birthdate
            end
          end
        end
      end
    end
  end
end
