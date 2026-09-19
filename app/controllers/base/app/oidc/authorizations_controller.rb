# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oidc
      class AuthorizationsController < Base::App::ApplicationController
        AUTHENTICATION_MODE = :open

        skip_before_action :set_region, raise: false

        def show
          url = initiate_oidc_session!(
            pt: base_app_root_path(ri: params[:ri].presence),
            screen_hint: screen_hint_param,
          )
          redirect_to_oidc_authorization_url(url)
        end

        private

        def screen_hint_param
          return "signup" if params[:screen_hint].to_s == "signup"
          return "signin" if params[:screen_hint].to_s == "signin"

          "signup"
        end
      end
    end
  end
end
