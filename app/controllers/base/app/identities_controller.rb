# typed: false
# frozen_string_literal: true

module Base
  module App
    class IdentitiesController < Base::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        render inertia: true, props: {
          title: "Identity",
          description: "Signed in",
          up_link: dashboard_up_link(label: t("base.shared.identity.up_link")),
          credential_warning: apple_only_credential_warning_props,
          sections: identity_hub_sections,
        }
      end

      private

      def identity_hub_sections
        [
          identity_profile_section,
          identity_security_section,
          identity_external_services_section,
          identity_account_section,
        ]
      end

      def identity_profile_section
        {
          heading: t("base.shared.identity.sections.profile"),
          items: [
            identity_hub_link(:emails, base_app_identity_emails_path(ri: params[:ri])),
            identity_hub_link(:telephones, base_app_identity_telephones_path(ri: params[:ri])),
            identity_hub_link(:birthdate, base_app_identity_birthdate_path(ri: params[:ri])),
          ],
        }
      end

      def identity_security_section
        {
          heading: t("base.shared.identity.sections.security"),
          items: [
            identity_auth_link(:passkey, :auth_app_settings_passkeys_url),
            identity_auth_link(:totp, :auth_app_settings_totps_url),
            { label: t("sign.app.settings.show.mfa"), href: base_app_identity_mfa_challenge_path(ri: params[:ri]) },
            { label: t("sign.app.settings.show.mfa_reset"), href: base_app_identity_mfa_reset_path(ri: params[:ri]) },
            identity_hub_link(:secrets, base_app_identity_secrets_path(ri: params[:ri])),
            identity_hub_link(:activities, base_app_identity_activities_path(ri: params[:ri])),
            identity_hub_link(:standing, base_app_identity_standing_path(ri: params[:ri])),
          ],
        }
      end

      def identity_external_services_section
        {
          heading: t("sign.app.settings.show.external_services"),
          items: [
            identity_auth_link(:google, :auth_app_settings_google_url),
            identity_auth_link(:apple, :auth_app_settings_apple_url),
          ],
        }
      end

      def identity_account_section
        {
          heading: t("base.shared.identity.sections.account"),
          items: [
            identity_hub_link(:withdrawal, new_base_app_identity_withdrawal_path(ri: params[:ri])),
          ],
        }
      end

      def identity_hub_link(key, href)
        { label: t(key, scope: "base.shared.identity.links"), href: href }
      end

      def identity_auth_link(key, route_helper)
        {
          label: t(key, scope: "controller.sign.app.setting.index"),
          href: public_send(
            route_helper,
            ri: params[:ri],
            host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            protocol: "https",
          ),
        }
      end
    end
  end
end
