# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Mfa
        class ResetsController < BaseController
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          step_up only: :create, scope: "settings_mfa"

          def show
            authorize!(current_client, to: :show?)
            render inertia: true, props: {
              title: t("sign.app.settings.show.mfa_reset"),
              reset_unavailable: t("sign.app.settings.mfa.show.reset_unavailable"),
              back_link: {
                label: t("sign.app.settings.show.back"),
                href: base_app_identity_path(ri: params[:ri]),
              },
            }
          end

          def create
            authorize!(current_client, to: :update?)
            current_client.update!(
              mfa_level_id: ClientMfaLevel::NOTHING,
              mfa_level_enabled: false,
            )
            CredentialSecurityTransition.call(
              actor: current_client,
              current_session: current_session,
              reason: :mfa_reset,
              affected_surface: "app",
              request: request,
            )
            redirect_to(
              base_app_identity_mfa_reset_path(ri: params[:ri]),
              status: :see_other,
            )
          end
        end
      end
    end
  end
end
