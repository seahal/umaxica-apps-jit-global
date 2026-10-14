# typed: false
# frozen_string_literal: true

module Tech
  module Org
    class DashboardsController < Tech::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private
      before_action :authenticate_browser_rp!

      public

      def show
        render :show
      end
    end
  end
end
