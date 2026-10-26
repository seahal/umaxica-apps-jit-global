# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      module Logouts
        class ConfirmationsController < ::Visa::App::Oidc::LogoutsController
          AUTHENTICATION_MODE = :open

          declare_authentication_mode! :open

          public

          def create
            confirm_oidc_end_session_logout
          end
        end
      end
    end
  end
end
