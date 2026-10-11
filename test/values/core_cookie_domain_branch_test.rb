# frozen_string_literal: true

require "test_helper"

class CoreCookieDomainBranchTest < ActiveSupport::TestCase
  test "normalize_configured and localhost helpers reject blank and bare localhost" do
    assert_nil CoreCookieDomain.send(:normalize_configured, "")
    assert_nil CoreCookieDomain.send(:normalize_configured, "HOST_ONLY")
    assert_nil CoreCookieDomain.send(:localhost_cookie_domain, "localhost")
    assert_nil CoreCookieDomain.send(:localhost_cookie_domain, "x")
    assert_not CoreCookieDomain.send(:domain_matches_host?, "", "app.example.com")
  end
end
