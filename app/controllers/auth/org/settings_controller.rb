# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class SettingsController < ::Auth::Org::ApplicationController
      # D-59: the settings index redirects to the owner surface; it is not a Sign Entry.
      sign_entry_classification! :excluded, reason: "signed-in settings surface, not a sign entry"

      AUTHENTICATION_MODE = :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        redirect_to_jump_url(
          base_org_identity_url(ri: params[:ri], host: base_rp_host, protocol: "https"),
          status: :see_other,
        )
      end
    end
  end
end
