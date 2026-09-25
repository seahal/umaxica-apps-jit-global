# typed: false
# frozen_string_literal: true

module Warp
  module Com
    class DashboardsController < Warp::Com::ApplicationController
      include ::WarpDashboardPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        render inertia: true, props: dashboard_page_props
      end
    end
  end
end
