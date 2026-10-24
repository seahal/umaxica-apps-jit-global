# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class SettingsController < ::Auth::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        redirect_to_jump_url(
          base_com_identity_url(ri: params[:ri], host: base_rp_host, protocol: "https"),
          status: :see_other,
        )
      end
    end
  end
end
