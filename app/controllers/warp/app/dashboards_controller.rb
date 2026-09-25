# typed: false
# frozen_string_literal: true

module Warp
  module App
    class DashboardsController < Warp::App::ApplicationController
      include ::WarpDashboardPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        render inertia: true, props: dashboard_page_props
      end
    end
  end
end
