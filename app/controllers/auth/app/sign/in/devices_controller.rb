# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        class DevicesController < ::Auth::App::ApplicationController
          include ::AuthenticationModeSwitchGuard

          AUTHENTICATION_MODE = :guest
          declare_authentication_mode! :guest

          public

          def show
            render plain: t("sign.app.authentication.device.placeholder")
          end
        end
      end
    end
  end
end
