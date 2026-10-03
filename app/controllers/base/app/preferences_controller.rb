# typed: false
# frozen_string_literal: true

module Base
  module App
    class PreferencesController < PreferencesBaseController
      include ::BasePreferenceIndexPage

      AUTHENTICATION_MODE = :open

      public

      def show
        # `inertia: true` resolves the component through the configured component_path_resolver,
        # which is controller_path + action_name: "base/app/preferences/show".
        render inertia: true, props: preference_index_page_props
      end

      protected

      def track_authenticated_session_activity?
        return false if (request.get? || request.head?) && action_name == "show"

        super
      end
    end
  end
end
