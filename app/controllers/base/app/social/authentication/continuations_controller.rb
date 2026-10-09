# typed: false
# frozen_string_literal: true

module Base
  module App
    module Social
      module Authentication
        # Social credentials use the ordinary Base admission before the Auth-local provider POST.
        class ContinuationsController < ::Base::App::ApplicationController
          include SocialCeremonyParams

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          def create
            social_provider_param
            redirect_to(base_app_sign_show_path(ri: params[:ri]), status: :see_other)
          end
        end
      end
    end
  end
end
