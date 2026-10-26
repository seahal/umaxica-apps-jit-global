# frozen_string_literal: true

module Visa
  module Com
    class RootsController < BareController
      include ::PreferenceGlobal

      AUTHENTICATION_MODE = :bare

      layout false

      before_action :set_region

      public

      def index
        @base_origin = Rails.configuration.x.boot_config.fetch(:hosts).base_corporate
      end
    end
  end
end
