# typed: false
# frozen_string_literal: true

module Xper
  module Com
    class RobotsController < BareController
      AUTHENTICATION_MODE = :bare

      public

      # FIXME: Replace this placeholder implementation once the final SEO delivery mechanism is in place.
      def index
        canonical_origin = Rails.configuration.x.boot_config.fetch(:hosts).xper_corporate.to_s
        render plain: "User-agent: *\nAllow: /\nSitemap: #{canonical_origin}/sitemap.xml\n"
      end
    end
  end
end
