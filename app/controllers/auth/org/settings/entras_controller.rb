# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      # Shows the operator the state of their Microsoft Entra ID link and hands
      # them to the sign-in ceremony.
      #
      # This surface never provisions. An OperatorEntraIdentity is created by an
      # administrator out of band, and signing in without one fails closed
      # (adr/org-entra-id-sign-in-boundary.md).
      #
      # There is no connection for the operator to choose: the org surface
      # federates a single tenant configured in Rails credentials
      # (adr/org-entra-single-tenant-credential-configuration.md). The only
      # question this screen answers is whether the ceremony can be started at
      # all, decided the same way Auth::Org::Social::SessionsController decides
      # it so that a kill switch closes both entry points together.
      class EntrasController < ::Auth::Org::ApplicationController
        include ::SurfaceInertiaPage
        include ::ExternalAuthenticationEndpoint

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        before_action :authorize_entra_settings!
        before_action :set_entra_identity

        def show
          render inertia: true, props: entra_show_props
        end

        def edit
          render inertia: true, props: entra_edit_props
        end

        def create
          unless entra_start_available?
            return render(
              inertia: "auth/org/settings/entras/edit",
              props: entra_edit_props,
              status: :service_unavailable,
            )
          end

          redirect_to(new_auth_org_social_entra_session_path(ri: params[:ri]), status: :see_other)
        end

        def destroy
          render inertia: "auth/org/settings/entras/edit",
                 props: entra_edit_props,
                 status: :unprocessable_content
        end

        private

        def entra_show_props
          {
            title: "Microsoft Entra ID",
            heading: "Microsoft Entra ID",
            back_link: { label: t("sign.org.settings.show.back"), href: auth_org_settings_path(ri: params[:ri]) },
            status: @entra_identity.present? ? "Connected" : "Not connected",
            edit_link: { label: t("actions.edit"), href: edit_auth_org_settings_entra_path(ri: params[:ri]) },
          }
        end

        # Disconnecting from settings is not offered until the operator lifecycle owner is defined,
        # so a connected identity gets the notice and no form at all.
        def entra_edit_props
          connected = @entra_identity.present?
          connectable = !connected && entra_start_available?

          {
            title: "Microsoft Entra ID",
            heading: "Microsoft Entra ID",
            back_link: {
              label: t("sign.org.settings.show.back"),
              href: auth_org_settings_entra_path(ri: params[:ri]),
            },
            connected: connected,
            connected_notice: if connected
                                "Disconnecting Microsoft Entra ID from settings is not available " \
                                  "until the operator lifecycle owner is defined."
                              end,
            # The same string the ceremony entry page shows, so the two screens
            # cannot disagree about why Entra is unusable right now.
            unavailable_notice: unavailable_notice(connected: connected, connectable: connectable),
            form: if connectable
                    {
                      action: auth_org_settings_entra_path(ri: params[:ri]),
                      submit_label: "Connect",
                    }
                  end,
          }
        end

        def unavailable_notice(connected:, connectable:)
          return if connected || connectable

          t("sign.org.authentication.entra.errors.provider_unavailable")
        end

        def authorize_entra_settings!
          authorize!(current_operator, to: :show?)
        end

        def set_entra_identity
          @entra_identity = OperatorEntraIdentity.find_by(
            operator_id: current_operator.id,
            status_id: OperatorEntraIdentityState::ACTIVE,
          )
        end

        def entra_start_available?
          external_authentication_allowed?(surface: "org", provider: "entra", operation: "login") &&
            external_authentication_start_available?(provider: "entra", operation: "login", context: {})
        end
      end
    end
  end
end
