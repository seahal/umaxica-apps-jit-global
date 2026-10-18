# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      class ApplesController < ::Auth::App::ApplicationController
        include ::SurfaceInertiaPage
        include ::TurnstilePageProps
        include CloudflareTurnstile
        include SocialAuth
        include ::SignSocialAuthenticationEndpoint
        include ::VerificationClient

        AUTHENTICATION_MODE = :private
        # Any ERB response that still leaves this controller - an error page, a shared ceremony
        # template - needs the ERB layout, because the slim Inertia shell has no `yield` and would
        # silently drop the body.
        layout :social_settings_layout

        before_action :authenticate_client!
        before_action :authorize_apple_settings!, only: %i(show edit create destroy)
        before_action :require_step_up_for_mutation!, only: %i(edit create destroy)
        before_action :authorize_social_unlink!, only: :destroy

        # Object-level authorization (ActionPolicy): the Apple link-status page reads the client's
        # own account, so gate owner-self via ClientPolicy#show? (mirrors the birthdate page).
        def show
          render_inertia_page(props: show_page_props)
        end

        def edit
          render_inertia_page(props: edit_page_props)
        end

        def create
          continue_social_authentication(provider: social_provider, intent: "link")
        end

        def destroy
          disconnect_social_authentication(provider: social_provider)
        end

        private

        # Renders one Inertia page and tells `social_settings_layout` that the slim Inertia shell is
        # the right layout for this response.
        def render_inertia_page(props:, component: true, status: :ok)
          @renders_inertia_page = true
          render inertia: component, props: props, status: status
        end

        def social_settings_layout
          @renders_inertia_page ? "auth/app/inertia" : "auth/app/application"
        end

        def authorize_apple_settings!
          authorize!(current_client, to: :show?)
        end

        def require_step_up_for_mutation!
          return render_unlink_blocked unless social_operation_allowed?

          scope = social_operation_scope
          return true if step_up_satisfied?(scope: scope)

          redirect_to(
            actor_verification_path(
              scope: scope,
              pt: encoded_relative_pt(edit_auth_app_settings_apple_path(ri: params[:ri])),
              ri: params[:ri],
            ),
            status: :see_other,
          )
          false
        end

        def social_operation_scope
          social_provider_linked? ? verification_scope : SOCIAL_LINK_SCOPE
        end

        def social_operation_allowed?
          return false if action_name == "create" && social_provider_linked?
          return true unless social_operation_scope == verification_scope

          social_unlink_allowed?
        end

        def social_unlink_allowed?
          identity = current_client.client_external_identities.effective_binding.find_by(
            provider: social_provider,
          )
          return true unless identity
          return false unless identity.active?

          AuthMethodGuard.can_remove_external_identity?(current_client, identity)
        end

        def render_unlink_blocked
          render_inertia_page(
            component: "auth/app/settings/apples/edit",
            props: edit_page_props,
            status: :unprocessable_content,
          )
          false
        end

        def show_page_props
          {
            title: t("controller.sign.app.setting.index.apple"),
            heading: t("controller.sign.app.setting.index.apple"),
            description: t("views.sign.app.settings.apples.show.description"),
            status: social_link_status_label,
            back_link: { label: t("sign.app.settings.show.back"), href: auth_app_settings_path },
            edit_link: {
              label: t("actions.edit"),
              href: edit_auth_app_settings_apple_path(ri: params[:ri]),
            },
          }
        end

        def social_link_status_label
          if current_client.active_social_provider?(social_provider)
            t("views.sign.app.settings.apples.show.linked")
          else
            t("views.sign.app.settings.apples.show.unlinked")
          end
        end

        def edit_page_props
          linked = current_client.active_social_provider?(social_provider)
          unlink_allowed =
            linked && social_unlink_allowed?

          {
            title: t("controller.sign.app.setting.index.apple"),
            heading: t("controller.sign.app.setting.index.apple"),
            description: t("views.sign.app.settings.apples.show.description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: auth_app_settings_apple_path(ri: params[:ri]),
            },
            unlink: unlink_props(linked: linked, allowed: unlink_allowed),
            connect: linked ? nil : connect_props,
            turnstile: unlink_allowed ? turnstile_stealth_props : nil,
          }
        end

        # The disconnect form exists only while the provider is linked, and stays disabled while
        # unlinking would leave the account without another sign-in method.
        def unlink_props(linked:, allowed:)
          return nil unless linked

          {
            action: auth_app_settings_apple_path(ri: params[:ri]),
            submit_label: t("actions.disconnect"),
            allowed: allowed,
            blocked_notice: allowed ? nil : t("errors.social_auth.insufficient_login_methods"),
          }
        end

        def connect_props
          {
            action: auth_app_settings_apple_path(ri: params[:ri]),
            label: t("actions.connect"),
          }
        end

        def social_provider_linked?
          action_name == "destroy" || current_client.active_social_provider?(social_provider)
        end

        def social_provider
          "apple"
        end
      end
    end
  end
end
