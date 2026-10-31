# typed: false
# frozen_string_literal: true

module Base
  module Com
    class PreferencesController < PreferencesBaseController
      include ::BasePreferenceIndexPage

      AUTHENTICATION_MODE = :open

      public

      # `inertia: true` resolves the component through the configured component_path_resolver,
      # which is controller_path + action_name: "base/com/preferences/show".
      def show
        render inertia: true, props: preference_index_page_props
      end

      private

      # The com surface has no dashboard; the preference index returns to the anonymous root.
      def preference_index_return_destination
        "root"
      end
    end
  end
end
