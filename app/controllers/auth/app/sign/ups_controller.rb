# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class UpsController < ::Auth::App::ApplicationController
        include ::SurfaceInertiaPage
        include SignUpSuspensionGuard
        include AppSignUpEntryPage
        include ::AuthCeremonyAdmission

        # Use :open instead of :guest so already-authenticated users reach the
        # action body and get redirected to their dashboard (see
        # `redirect_logged_in_direct_entry!`) instead of receiving a 403 from
        # the guest enforcement. Matches the sibling InsController policy.
        AUTHENTICATION_MODE = :open

        before_action :reject_suspended_sign_up!
        declare_authentication_mode! :open

        def show
          admit_or_render_sign_ceremony!(expected_intent: "sign_up") { render_sign_up_entry_page! }
        end

        private

        def sign_up_surface = :app

        # Logged-in users hitting /sign/up directly are sent to their post-auth
        # landing instead of receiving a 403. The 403 surfaced as a hard error
        # in the cross-host redirect chain when the SSO handshake briefly
        # revisited this endpoint.
        def redirect_logged_in_direct_entry!
          redirect_to(
            base_app_root_url(ri: current_region_identifier, host: base_authority_host),
            allow_other_host: true,
          )
        end

        # Logged-in direct entry returns to Base Root. Unauthenticated direct entry bridges to Base admission.
        alias handle_logged_in_direct_entry! redirect_logged_in_direct_entry!

        def render_method_selection!
          render_sign_up_entry_page!
        end

        # The action's component name would be `auth/app/sign/ups/show`; the page it renders is the
        # registration entry page, so it is named for the page rather than for the route.
        def render_sign_up_entry_page!
          render inertia: AppSignUpEntryPage::SIGN_UP_ENTRY_COMPONENT, props: sign_up_entry_page_props
        end
      end
    end
  end
end
