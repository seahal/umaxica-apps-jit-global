# typed: false
# frozen_string_literal: true

module Sitemap
  extend ActiveSupport::Concern

  BROWSER_CACHE_TTL = 5.minutes
  CDN_CACHE_TTL = 10.minutes

  private

  # The sitemap is public and identical for every visitor, so it opts into shared caching through
  # `expires_in` rather than a hand-written header: on Global policy roots `DefaultNoStore` would
  # override a directly written `Cache-Control` (adr/global-and-publishing-default-no-store-policy.md).
  # The extra option is emitted verbatim as `s-maxage=600`.
  def show_xml
    expires_in(BROWSER_CACHE_TTL, public: true, "s-maxage": CDN_CACHE_TTL.to_i)
    response.set_header("Surrogate-Control", "max-age=#{CDN_CACHE_TTL.to_i}")
    render formats: :xml
  end
end
