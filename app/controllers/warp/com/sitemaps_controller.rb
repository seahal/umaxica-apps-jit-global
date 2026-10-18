# typed: false
# frozen_string_literal: true

module Warp
  module Com
    class SitemapsController < BareController
      include ::Sitemap

      AUTHENTICATION_MODE = :bare

      def show
        show_xml
      end
    end
  end
end
