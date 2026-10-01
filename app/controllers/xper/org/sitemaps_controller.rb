# typed: false
# frozen_string_literal: true

module Xper
  module Org
    class SitemapsController < BareController
      AUTHENTICATION_MODE = :bare

      public

      # FIXME: Replace this placeholder implementation once the final SEO delivery mechanism is in place.
      def index
        canonical_origin = Rails.configuration.x.boot_config.fetch(:hosts).xper_staff.to_s
        render xml: <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <url><loc>#{ERB::Util.html_escape(canonical_origin)}/</loc></url>
          </urlset>
        XML
      end
    end
  end
end
