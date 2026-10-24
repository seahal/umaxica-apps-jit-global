# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      class UpsController < ::Auth::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::AuthCeremonyAdmission
        include ::SignEntryExit

        AUTHENTICATION_MODE = :guest

        declare_authentication_mode! :guest, no_redirect: true

        def show
          admit_or_render_sign_ceremony!(expected_intent: auth_ceremony_entry_intent) { render_method_selection! }
        end

        private

        def auth_ceremony_entry_intent = "sign_up"

        def sign_up_surface = :com

        def render_method_selection!
          render inertia: "auth/com/sign_ups/new", props: sign_up_method_props
        end

        def sign_up_method_props
          entry_params = { ct: params[:ct], ri: params[:ri] }

          {
            title: t("sign.com.registration.new.page_title"),
            description: nil,
            suspended_notice: nil,
            methods: sign_up_method_links(entry_params),
            # An OIDC-bound page moves to Sign In only through the Switch form (D06).
            links: sign_entry_parent_bound? ? [] : sign_up_footer_links(entry_params),
            **sign_entry_exit_forms(switch_to: "sign_in", switch_label: t("sign.com.registration.new.links.sign_in")),
          }
        end

        def sign_entry_exit_sign_up_cycle_class = VisitorSignUpFlow

        def sign_entry_exit_cancellation_path = auth_com_sign_cancellation_path(ri: params[:ri])

        def sign_entry_exit_switch_path = auth_com_sign_switch_path(ri: params[:ri])

        def sign_up_method_links(entry_params)
          [
            {
              key: "email",
              label: t("sign.com.registration.new.methods.email.cta"),
              href: new_auth_com_sign_up_email_path(**entry_params),
            },
            {
              key: "telephone",
              label: t("sign.com.registration.new.methods.telephone.cta"),
              href: new_auth_com_sign_up_telephone_path(**entry_params),
            },
          ]
        end

        def sign_up_footer_links(entry_params)
          [
            {
              key: "sign_in",
              label: t("sign.com.registration.new.links.sign_in"),
              href: auth_com_sign_in_sentry_path(**entry_params),
            },
          ]
        end
      end
    end
  end
end
