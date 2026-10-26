# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module Up
        class SentriesController < ::Auth::Com::ApplicationController
          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          public

          def show
            return if enforce_sign_entry_sentry!

            redirect_to(
              auth_com_sign_up_path(entry_ref: params[:entry_ref], pt: signed_pt_param),
              status: :see_other,
            )
          end

          private

          def enforce_sign_entry_sentry!
            state = SignEntrySentryResolver.call(surface: "com", flow: "sign_up")
            return false if state.allowed?

            refuse_sign_entry_sentry!(flow: "sign_up", enforcement_point: "sentry")
            true
          end
        end
      end
    end
  end
end
