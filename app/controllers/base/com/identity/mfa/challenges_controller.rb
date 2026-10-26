# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Mfa
        class ChallengesController < ::Base::Com::ApplicationController
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authorize_mfa_challenge!, only: %i(show update)

          public

          def show
            render inertia: true, props: mfa_challenge_page_props
          end

          # adr/authentication-security-mode.md and the consolidation ADR 2.2/2.5: ADVANCED needs two
          # active Passkeys, counted under the owner lock; leaving ADVANCED revokes every session.
          def update
            requested = requested_security_mode_id
            previous = current_visitor.security_mode_id
            current_visitor.with_lock do
              if requested == VisitorSecurityMode::ADVANCED && active_passkey_count < 2
                raise ArgumentError, "ADVANCED requires two active passkeys"
              end

              current_visitor.update!(security_mode_id: requested)
            end
            if previous != requested
              downgrade = requested == VisitorSecurityMode::NORMAL
              CredentialSecurityTransition.call(
                actor: current_visitor,
                current_session: current_session,
                reason: downgrade ? :security_mode_normal : :security_mode_advanced,
                affected_surface: "com",
                revoke_current: downgrade,
                request: request,
              )
            end
            redirect_to(base_com_identity_mfa_challenge_path(ri: params[:ri]))
          rescue ActiveRecord::RecordInvalid, ArgumentError
            render inertia: "base/com/identity/mfa/challenges/show",
                   props: mfa_challenge_page_props(error: t("sign.app.settings.mfa.update.failure")),
                   status: :unprocessable_content
          end

          private

          def authorize_mfa_challenge! = authorize!(current_visitor, to: :"#{action_name}?")

          def verification_required_action? = %w(show update).include?(action_name)

          def verification_scope = "settings_mfa"

          def mfa_challenge_page_props(error: nil)
            {
              title: t("sign.app.settings.mfa.show.title"),
              reset_unavailable: t("sign.app.settings.mfa.show.reset_unavailable"),
              toggle_title: t("sign.app.settings.mfa.show.toggle_title"),
              state_label: current_visitor.security_mode_advanced? ?
                t("sign.app.settings.mfa.show.enabled") : t("sign.app.settings.mfa.show.disabled"),
              back_link: {
                label: t("sign.app.settings.show.back"),
                href: base_com_identity_path(ri: params[:ri]),
              },
              form: security_mode_form,
              form_unavailable:
                security_mode_form ? nil : t("sign.app.settings.mfa.show.advanced_requires_two_passkeys"),
              error: error,
            }
          end

          # The page offers the one switch the owner can make now: back to NORMAL, or up to ADVANCED
          # once two active Passkeys exist.
          def security_mode_form
            if current_visitor.security_mode_advanced?
              { action: base_com_identity_mfa_challenge_path(ri: params[:ri]),
                security_mode_id: VisitorSecurityMode::NORMAL,
                submit_label: t("sign.app.settings.mfa.show.switch_to_normal"), }
            elsif active_passkey_count >= 2
              { action: base_com_identity_mfa_challenge_path(ri: params[:ri]),
                security_mode_id: VisitorSecurityMode::ADVANCED,
                submit_label: t("sign.app.settings.mfa.show.switch_to_advanced"), }
            end
          end

          def requested_security_mode_id
            mode = Integer(params.dig(:user, :security_mode_id).to_s, 10)
            return mode if VisitorSecurityMode::DEFAULTS.include?(mode)

            raise ArgumentError, "unsupported security mode"
          end

          def active_passkey_count
            current_visitor.visitor_passkeys.where(status_id: VisitorPasskeyStatus::ACTIVE).count
          end
        end
      end
    end
  end
end
