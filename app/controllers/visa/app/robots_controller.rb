# typed: false
# frozen_string_literal: true

module Visa
  module App
    class RobotsController < BareController
      include ::Robots

      AUTHENTICATION_MODE = :bare

      public

      def index
        show_plain_text
      end

      private

      def robots_txt
        "User-agent: *\nDisallow: /\n"
      end
    end
  end
end
