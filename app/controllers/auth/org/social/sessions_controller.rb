# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Social
      # Starts the OmniAuth-based Microsoft Entra ID sign-in ceremony.
      #
      # GET  /social/entra/session/new
      # POST /social/entra/session
      #
      # Mirrors Auth::App::Social::SessionsController: both implement the
      # surface-neutral SocialCeremonyEntry, which validates the provider,
      # applies the availability gate, and hands the POST to the OmniAuth
      # request phase with a 307.
      #
      # The org surface has no social sign-up and no link/step-up intent: Entra
      # sign-in performs no JIT provisioning, so an operator without a
      # pre-provisioned OperatorEntraIdentity cannot become one by signing in
      # (adr/org-entra-id-sign-in-boundary.md). The neutral concern's defaults
      # already express that, so only the three required hooks are implemented.
      class SessionsController < ::Auth::Org::ApplicationController
        include SocialCeremonyEntry
        include ::SurfaceInertiaPage
        include ::AuthenticationModeSwitchGuard

        AUTHENTICATION_MODE = :guest

        PT_SESSION_KEY = :auth_org_entra_omniauth_pt

        PROVIDERS = %w(entra).freeze

        rate_limit(
          to: 20,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "auth_org_sign_in_entra",
          name: "ceremony_start_ip_burst",
          store: rate_limit_store,
          only: :create,
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )

        def new
          stash_pt!
          @provider_available = entra_start_available?
          render inertia: true, props: entra_entry_props
        end

        # POST /social/entra/session
        def create
          stash_pt!

          unless entra_start_available?
            @provider_available = false
            return render(
              inertia: "auth/org/social/sessions/new",
              props: entra_entry_props,
              status: :service_unavailable,
            )
          end

          handoff_social_ceremony!
        end

        private

        # The request phase is a document POST to the OmniAuth endpoint, like the app surface's
        # Google and Apple buttons. The tenant is fixed in configuration, so there is nothing for
        # the operator to choose and the page carries no input.
        def entra_entry_props
          {
            title: t("sign.org.authentication.entra.new.page_title"),
            unavailable_notice: if @provider_available
                                  nil
                                else
                                  t("sign.org.authentication.entra.errors.provider_unavailable")
                                end,
            form: (@provider_available ? { action: "/social/entra",
                                           submit_label: t("sign.org.authentication.entra.new.submit"), } : nil),
          }
        end

        def social_ceremony_surface = "org"

        def social_ceremony_providers = PROVIDERS

        def social_ceremony_abort_path = auth_org_sign_in_path(ri: params[:ri])

        def stash_pt!
          session[PT_SESSION_KEY] = signed_pt_param if signed_pt_param.present?
        end

        # Mirrors the strategy's own request-phase gate
        # (UmaxicaEntra#entra_start_available?) so a :social_ceremony_org_entra kill
        # switch stops the ceremony at the entry point rather than only after
        # the operator has pressed the button.
        def entra_start_available?
          external_authentication_allowed?(surface: "org", provider: "entra", operation: "login") &&
            external_authentication_start_available?(provider: "entra", operation: "login", context: {})
        end
      end
    end
  end
end
