# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Mfa
        class ChallengesController < BaseController
          include ::SurfaceInertiaPage
          include VerificationClient

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authorize_mfa_challenge!, only: %i(show update)
          def show
            render inertia: true, props: mfa_challenge_page_props
          end

          def update
            previous_mfa_level_id = current_client.mfa_level_id
            mfa_level_id = requested_mfa_level_id
            current_client.update!(mfa_level_id: mfa_level_id, mfa_level_enabled: mfa_level_id != ClientMfaLevel::NOTHING)
            CredentialSecurityTransition.call(
              actor: current_client,
              current_session: current_session,
              reason: (mfa_level_id == ClientMfaLevel::NOTHING) ? :mfa_disabled : :mfa_level_changed,
              affected_surface: "app",
              request: request,
            ) if previous_mfa_level_id != mfa_level_id
            redirect_to(
              base_app_identity_mfa_challenge_path(ri: params[:ri]),
            )
          rescue ActiveRecord::RecordInvalid, ArgumentError
            render inertia: "base/app/identity/mfa/challenges/show",
                   props: mfa_challenge_page_props(error: t("sign.app.settings.mfa.update.failure")),
                   status: :unprocessable_content
          end

          private

          def authorize_mfa_challenge! = authorize!(current_client, to: :"#{action_name}?")

          def verification_required_action? = %w(show update).include?(action_name)

          def verification_scope = "settings_mfa"

          def mfa_challenge_page_props(error: nil)
            {
              title: t("sign.app.settings.mfa.show.title"),
              reset_unavailable: t("sign.app.settings.mfa.show.reset_unavailable"),
              toggle_title: t("sign.app.settings.mfa.show.toggle_title"),
              state_label: current_client.mfa_level_enabled? ?
                t("sign.app.settings.mfa.show.enabled") : t("sign.app.settings.mfa.show.disabled"),
              back_link: {
                label: t("sign.app.settings.show.back"),
                href: base_app_identity_path(ri: params[:ri]),
              },
              error: error,
            }
          end

          def requested_mfa_level_id
            mfa_level_id = Integer(params.dig(:user, :mfa_level_id).to_s, 10)
            allowed = [
              ClientMfaLevel::NOTHING,
              ClientMfaLevel::WEAK,
              ClientMfaLevel::MEDIUM,
              ClientMfaLevel::FULL,
            ]
            return mfa_level_id if allowed.include?(mfa_level_id)

            raise ArgumentError, "unsupported multi factor level"
          end
        end
      end
    end
  end
end
