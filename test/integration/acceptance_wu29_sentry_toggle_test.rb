# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWu29SentryToggleTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  SURFACES = [
    ["app", "PUBLIC_AUTH_SERVICE_URL"],
    ["com", "PUBLIC_AUTH_CORPORATE_URL"],
    ["org", "PUBLIC_AUTH_STAFF_URL"],
  ].freeze

  FLOWS = %w(sign_in sign_up).freeze

  setup do
    @previous_flags = SURFACES.flat_map do |surface, _host_env|
      FLOWS.map do |flow|
        feature = FeatureFlags::REGISTRY.fetch("#{flow}_available_#{surface}".to_sym).name
        [feature, Flipper.enabled?(feature)]
      end
    end.to_h
  end

  teardown do
    @previous_flags.each do |feature, enabled|
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "A29-7: each surface and flow reads availability again on the next request" do
    SURFACES.each do |surface, host_env|
      FLOWS.each do |flow|
        feature = FeatureFlags::REGISTRY.fetch("#{flow}_available_#{surface}".to_sym).name
        path = flow == "sign_in" ? "/sign/in/sentry" : "/sign/up/sentry"
        host = ENV.fetch(host_env)
        browser = open_session
        browser.host!(host)
        browser.https!

        Flipper.enable(feature)
        browser.get(path, params: { ri: "jp" })

        assert_equal 303, browser.response.status, "#{surface} #{flow} allowed before the flag changes"
        assert_equal "/sign/#{flow == "sign_in" ? "in" : "up"}", URI.parse(browser.response.location).path

        Flipper.disable(feature)
        browser.get(path, params: { ri: "jp" })

        assert_equal 503, browser.response.status, "#{surface} #{flow} must observe ALLOWED → BLOCKED"
        assert_equal "no-store", browser.response.headers["Cache-Control"]

        Flipper.enable(feature)
        browser.get(path, params: { ri: "jp" })

        assert_equal 303, browser.response.status, "#{surface} #{flow} must observe BLOCKED → ALLOWED"
        assert_equal "/sign/#{flow == "sign_in" ? "in" : "up"}", URI.parse(browser.response.location).path
      end
    end
  end
end
