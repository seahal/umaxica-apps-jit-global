# typed: false
# frozen_string_literal: true

module Warp
  module Org
    class SettingsController < Warp::Org::ApplicationController
      include ::WarpSettingsPage

      # Reachable from the anonymous Warp landing, which links here before the visitor signs in.
      AUTHENTICATION_MODE = :open

      def show
        render inertia: true, props: settings_page_props
      end
    end
  end
end
