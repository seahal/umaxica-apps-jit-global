# typed: false
# frozen_string_literal: true

require "ostruct"
require "test_helper"
# require "helpers/global_test_support"

class CookieDomainTest < ActiveSupport::TestCase
  def stub_creds(_key, value)
    creds_mock = Object.new
    creds_mock.define_singleton_method(:option) { |_key| value }
    Rails.stub(:app, OpenStruct.new(creds: creds_mock)) do
      yield
    end
  end

  test "for returns nil when env variable is blank and request host is localhost" do
    stub_creds(:COOKIE_DOMAIN_APP, nil) do
      result = CoreCookieDomain.for(surface: :app, request_host: "localhost")

      assert_nil result
    end
  end

  test "for returns nil when env variable is set to HOST_ONLY" do
    stub_creds(:COOKIE_DOMAIN_APP, "HOST_ONLY") do
      result = CoreCookieDomain.for(surface: :app, request_host: "app.example.com")

      assert_nil result
    end
  end

  test "for derives domain from request host" do
    stub_creds(:COOKIE_DOMAIN_APP, nil) do
      result = CoreCookieDomain.for(surface: :app, request_host: "app.example.com")

      assert_equal ".example.com", result
    end
  end

  test "for derives domain from request host with subdomain" do
    stub_creds(:COOKIE_DOMAIN_APP, nil) do
      result = CoreCookieDomain.for(surface: :app, request_host: "wwww.app.example.com")

      assert_equal ".example.com", result
    end
  end

  test "for handles IP address" do
    stub_creds(:COOKIE_DOMAIN_APP, nil) do
      result = CoreCookieDomain.for(surface: :app, request_host: "192.168.1.1")

      assert_equal ".1.1", result
    end
  end

  test "for uses configured env variable" do
    stub_creds(:COOKIE_DOMAIN_ORG, nil) do
      result = CoreCookieDomain.for(surface: :org, request_host: "localhost")

      assert_nil result
    end
  end
end
