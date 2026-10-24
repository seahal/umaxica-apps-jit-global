# typed: false
# frozen_string_literal: true

module Auth
  module App
    class SettingsController < ::Auth::App::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        redirect_to_jump_url(
          base_app_identity_url(ri: params[:ri], host: base_rp_host, protocol: "https"),
          status: :see_other,
        )
      end
    end
  end
end
