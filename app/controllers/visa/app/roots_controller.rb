# frozen_string_literal: true

module Visa
  module App
    class RootsController < BareController
      include ::PreferenceGlobal

      AUTHENTICATION_MODE = :bare

      layout false

      before_action :set_region

      public

      def index
        @base_origin = Rails.configuration.x.boot_config.fetch(:hosts).base_service
      end
    end
  end
end
