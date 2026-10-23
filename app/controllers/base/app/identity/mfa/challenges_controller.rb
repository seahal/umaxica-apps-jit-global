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

          # adr/authentication-security-mode.md and the consolidation ADR 2.2/2.5: ADVANCED needs two
          # active Passkeys, counted under the owner lock; leaving ADVANCED revokes every session.
          def update
            requested = requested_security_mode_id
            previous = current_client.security_mode_id
            current_client.with_lock do
              if requested == ClientSecurityMode::ADVANCED && active_passkey_count < 2
                raise ArgumentError, "ADVANCED requires two active passkeys"
              end

              current_client.update!(security_mode_id: requested)
            end
            if previous != requested
              downgrade = requested == ClientSecurityMode::NORMAL
              CredentialSecurityTransition.call(
                actor: current_client,
                current_session: current_session,
                reason: downgrade ? :security_mode_normal : :security_mode_advanced,
                affected_surface: "app",
                revoke_current: downgrade,
                request: request,
              )
            end
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
              state_label: current_client.security_mode_advanced? ?
                t("sign.app.settings.mfa.show.enabled") : t("sign.app.settings.mfa.show.disabled"),
              back_link: {
                label: t("sign.app.settings.show.back"),
                href: base_app_identity_path(ri: params[:ri]),
              },
              error: error,
            }
          end

          def requested_security_mode_id
            mode = Integer(params.dig(:user, :security_mode_id).to_s, 10)
            return mode if ClientSecurityMode::DEFAULTS.include?(mode)

            raise ArgumentError, "unsupported security mode"
          end

          def active_passkey_count
            current_client.client_passkeys.where(status_id: ClientPasskeyStatus::ACTIVE).count
          end
        end
      end
    end
  end
end
