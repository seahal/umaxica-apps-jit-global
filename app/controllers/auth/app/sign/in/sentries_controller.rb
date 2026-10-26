# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        class SentriesController < ::Auth::App::ApplicationController
          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          public

          def show
            return if enforce_sign_entry_sentry!

            redirect_to(
              auth_app_sign_in_path(entry_ref: params[:entry_ref], pt: signed_pt_param),
              status: :see_other,
            )
          end

          private

          def enforce_sign_entry_sentry!
            state = SignEntrySentryResolver.call(surface: "app", flow: "sign_in")
            return false if state.allowed?

            refuse_sign_entry_sentry!(flow: "sign_in", enforcement_point: "sentry")
            true
          end
        end
      end
    end
  end
end
