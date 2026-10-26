# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      class UpsController < ::Auth::Org::ApplicationController
        include ::SurfaceInertiaPage
        include ::AuthCeremonyAdmission

        AUTHENTICATION_MODE = :guest

        helper Auth::Org::SignUpsHelper
        declare_authentication_mode! :guest, no_redirect: true

        def show
          admit_or_render_sign_ceremony!(expected_intent: auth_ceremony_entry_intent) { render_method_selection! }
        end

        private

        def auth_ceremony_entry_intent = "sign_up"

        def sign_up_surface = :org

        def render_method_selection!
          render inertia: true, props: sign_up_entry_props
        end

        def sign_up_entry_props
          region = params[:ri]

          {
            title: t("sign.org.ups.new.heading"),
            description: t("sign.org.ups.new.description"),
            suspended_notice: nil,
            recruit: {
              prompt: t("sign.org.ups.new.recruit_prompt"),
              label: t("sign.org.ups.new.recruit_link_text"),
              href: helpers.sign_org_recruit_contact_url,
            },
            # Direct entry only. An RP-initiated ceremony asked for a sign-up, so the page must not
            # offer a detour into sign-in; the same rule governs the reciprocal link on
            # auth/org/sign/ins#show.
            sign_in_link: if @oidc_authorization_intent.blank?
                            {
                              label: t("sign.org.ups.new.links.sign_in"),
                              href: auth_org_sign_in_sentry_path(pt: signed_pt_param, ri: region),
                            }
                          end,
            cancel_link: {
              label: t("actions.cancel"),
              href: auth_org_root_path,
            },
          }
        end
      end
    end
  end
end
