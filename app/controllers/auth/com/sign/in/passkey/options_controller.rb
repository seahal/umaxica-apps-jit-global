# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        module Passkey
          class OptionsController < ::Auth::Com::ApplicationController
            include ::PasskeySignInFlow
            include ::AuthenticationModeSwitchGuard

            AUTHENTICATION_MODE = :guest
            declare_authentication_mode! :guest
            before_action :start_minimum_response_budget
            after_action :enforce_minimum_response_budget

            rate_limit(
              to: 5,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "auth_com_sign_in",
              name: "passkey_options_ip_burst",
              store: rate_limit_store,
              with: -> { render_rate_limited(retry_after: 60) },
            )
            rate_limit(
              to: 20,
              within: 15.minutes,
              by: -> { request.remote_ip },
              scope: "auth_com_sign_in",
              name: "passkey_options_ip_sustained",
              store: rate_limit_store,
              with: -> {
                render_rate_limited(retry_after: 900)
              },
            )

            def create = options

            private
          end
        end
      end
    end
  end
end
