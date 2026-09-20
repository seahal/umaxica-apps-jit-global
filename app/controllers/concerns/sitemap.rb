# typed: false
# frozen_string_literal: true

module Sitemap
  extend ActiveSupport::Concern

  BROWSER_CACHE_TTL = 5.minutes
  CDN_CACHE_TTL = 10.minutes

  private

  def show_xml
    response.set_header(
      "Cache-Control",
      "public, max-age=#{BROWSER_CACHE_TTL.to_i}, s-maxage=#{CDN_CACHE_TTL.to_i}",
    )
    response.set_header("Surrogate-Control", "max-age=#{CDN_CACHE_TTL.to_i}")
    render formats: :xml
  end
end
