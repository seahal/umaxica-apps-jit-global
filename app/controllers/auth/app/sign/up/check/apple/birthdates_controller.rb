# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Apple
            class BirthdatesController < ::Auth::App::ApplicationController
              include SignUpExplicitStepControllerSupport

              include SignUpSocialBirthdateSupport

              include SignUpSocialCheckBirthdateControllerSupport

              include ::SurfaceInertiaPage
              include AppSignUpCheckpointPage

              AUTHENTICATION_MODE = :open

              private

              def sign_up_family = "apple"
            end
          end
        end
      end
    end
  end
end
