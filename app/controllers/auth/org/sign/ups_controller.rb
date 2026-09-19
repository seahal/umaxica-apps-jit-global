# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      class UpsController < ::Auth::Org::ApplicationController
        include SignUpSuspensionGuard
        include ::SurfaceInertiaPage
        include ::AuthCeremonyAdmission

        AUTHENTICATION_MODE = :guest

        before_action :reject_suspended_sign_up!
        helper Auth::Org::SignUpsHelper
        declare_authentication_mode! :guest, no_redirect: true

        def show
          admit_or_render_sign_ceremony!(expected_intent: "sign_up") { render_method_selection! }
        end

        private

        def sign_up_surface = :org

        def render_suspended_sign_up!
          render inertia: "auth/org/sign/ups/show", props: suspended_props, status: :service_unavailable
        end

        def reject_logged_in_direct_entry!
          render plain: I18n.t("errors.messages.already_authenticated"), status: :forbidden
        end

        # Logged-in direct entry is refused; unauthenticated direct entry bridges to Base admission.
        alias handle_logged_in_direct_entry! reject_logged_in_direct_entry!

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
                              href: auth_org_sign_in_path(pt: signed_pt_param, ri: region),
                            }
                          end,
            back_to_root: {
              label: t("sign.org.ups.new.back_to_root"),
              href: auth_org_root_path,
            },
          }
        end

        # The sign_up_suspended_org kill switch is on: send the notice instead of entry points that
        # would start a registration the guard is about to reject anyway.
        def suspended_props
          {
            title: t("sign.org.ups.new.heading"),
            description: nil,
            suspended_notice: t("errors.messages.sign_up_suspended"),
            recruit: nil,
            sign_in_link: nil,
            back_to_root: nil,
          }
        end
      end
    end
  end
end
