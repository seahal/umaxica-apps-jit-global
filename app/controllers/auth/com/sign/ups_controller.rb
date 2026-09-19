# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      class UpsController < ::Auth::Com::ApplicationController
        include SignUpSuspensionGuard
        include ::SurfaceInertiaPage
        include ::AuthCeremonyAdmission

        AUTHENTICATION_MODE = :guest

        before_action :reject_suspended_sign_up!
        declare_authentication_mode! :guest, no_redirect: true

        def show
          admit_or_render_sign_ceremony!(expected_intent: "sign_up") { render_method_selection! }
        end

        private

        def sign_up_surface = :com

        # `SignUpSuspensionGuard` re-renders this surface's own entry page; that page is an Inertia
        # component rather than a template, and the 503 stays exactly as it was.
        def render_suspended_sign_up!
          render inertia: "auth/com/sign_ups/new", props: sign_up_method_props, status: :service_unavailable
        end

        def reject_logged_in_direct_entry!
          render plain: I18n.t("errors.messages.already_authenticated"), status: :forbidden
        end

        # Logged-in direct entry is refused; unauthenticated direct entry bridges to Base admission.
        alias handle_logged_in_direct_entry! reject_logged_in_direct_entry!

        def render_method_selection!
          render inertia: "auth/com/sign_ups/new", props: sign_up_method_props
        end

        # `@sign_up_available == false` means the sign_up_suspended_<surface> kill switch is on:
        # send the notice instead of entry points that would start a registration the guard is
        # about to reject anyway.
        def sign_up_method_props
          suspended = @sign_up_available == false
          entry_params = { ct: params[:ct], ri: params[:ri] }

          {
            title: t("sign.app.registration.new.page_title"),
            description: nil,
            suspended_notice: suspended ? t("errors.messages.sign_up_suspended") : nil,
            methods: suspended ? [] : sign_up_method_links(entry_params),
            links: suspended ? [] : sign_up_footer_links(entry_params),
          }
        end

        def sign_up_method_links(entry_params)
          [
            {
              key: "email",
              label: t("sign.app.registration.new.methods.email.cta"),
              href: new_auth_com_sign_up_email_path(**entry_params),
            },
            {
              key: "telephone",
              label: t("sign.app.registration.new.methods.telephone.cta"),
              href: new_auth_com_sign_up_telephone_path(**entry_params),
            },
          ]
        end

        def sign_up_footer_links(entry_params)
          [
            {
              key: "sign_in",
              label: t("sign.app.registration.new.links.sign_in"),
              href: auth_com_sign_in_path(**entry_params),
            },
          ]
        end
      end
    end
  end
end
