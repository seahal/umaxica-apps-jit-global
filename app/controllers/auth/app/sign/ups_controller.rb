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

        # :open rather than :guest so an admitted ceremony continuation reaches
        # `admit_or_render_sign_ceremony!`, which itself refuses a new Sign from an
        # authenticated browser. Matches the sibling InsController policy.
        AUTHENTICATION_MODE = :open

        before_action :reject_suspended_sign_up!
        declare_authentication_mode! :open

        def show
          admit_or_render_sign_ceremony!(expected_intent: auth_ceremony_entry_intent) { render_sign_up_entry_page! }
        end

        private

        def auth_ceremony_entry_intent = "sign_up"

        def sign_up_surface = :app

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
