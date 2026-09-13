# typed: false
# frozen_string_literal: true

require "test_helper"

# The banner query moved out of ApplicationHelper when the Inertia surface layout became React:
# shared props are built in a controller, which cannot call a view helper. These cases came with it.
class CurrentBannerQueryTest < ActiveSupport::TestCase
  test "rejects invalid banner inputs" do
    error = assert_raises(ArgumentError) { CurrentBannerQuery.call(tld: :bad, region: :jp, domain: :news) }

    assert_match(/Invalid tld/, error.message)

    error = assert_raises(ArgumentError) { CurrentBannerQuery.call(tld: :app, region: :jp, domain: :bad) }

    assert_match(/Invalid domain/, error.message)

    error = assert_raises(ArgumentError) { CurrentBannerQuery.call(tld: :app, region: :us, domain: :sign) }

    assert_match(/Invalid region/, error.message)
  end

  test "normalizes a global region to ww for the sign and acme domains" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      assert_equal client_banners(:newer_current_user_banner),
                   CurrentBannerQuery.call(tld: :app, region: :global, domain: :sign)
      assert_equal client_banners(:newer_current_user_banner),
                   CurrentBannerQuery.call(tld: :app, region: :global, domain: :acme)
    end
  end
end
