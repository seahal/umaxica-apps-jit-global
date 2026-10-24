# typed: false
# frozen_string_literal: true

require "test_helper"

class SignEntrySentryTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
    com: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
    org: ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
  }.freeze

  FLOWS = %i(sign_in sign_up).freeze

  teardown do
    %i(
      sign_in_available_app sign_up_available_app
      sign_in_available_com sign_up_available_com
      sign_in_available_org sign_up_available_org
    ).each { |feature| Flipper.enable(feature) }
  end

  SURFACES.each do |surface, host|
    FLOWS.each do |flow|
      test "#{surface} #{flow} sentry redirects to its fixed entry when allowed" do
        host!(host)
        Flipper.enable(FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name)

        entry_name = (flow == :sign_in) ? "in" : "up"
        get public_send(:"auth_#{surface}_sign_#{entry_name}_sentry_path"),
            params: { entry_ref: "server-entry-ref", pt: "untrusted-or-signed", ri: "jp" },
            headers: host_headers(host)

        assert_response :see_other
        location = URI.parse(response.location)

        assert_equal "/sign/#{(flow == :sign_in) ? "in" : "up"}", location.path
        query = Rack::Utils.parse_nested_query(location.query.to_s)

        assert_equal "server-entry-ref", query.fetch("entry_ref")
        assert_nil query["pt"], "an invalid target must not be forwarded"
      end

      test "#{surface} #{flow} sentry refuses without a cacheable response when blocked" do
        host!(host)
        Flipper.disable(FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name)

        entry_name = (flow == :sign_in) ? "in" : "up"
        get public_send(:"auth_#{surface}_sign_#{entry_name}_sentry_path"), headers: host_headers(host)

        assert_response :service_unavailable
        assert_equal "no-store", response.headers["Cache-Control"]
        assert_equal "no-referrer", response.headers["Referrer-Policy"]
        assert_nil response.headers["Retry-After"]
      end

      test "#{surface} #{flow} sentry refusal records one reason-coded event" do
        host!(host)
        Flipper.disable(FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name)
        messages = []

        Rails.logger.stub(:info, ->(*args, &block) { messages << (args.first || block&.call).to_s }) do
          flow_name = (flow == :sign_in) ? "in" : "up"
          get public_send(:"auth_#{surface}_sign_#{flow_name}_sentry_path"),
              headers: host_headers(host)
        end

        refusal_events =
          messages.filter_map do |message|
            parsed = JSON.parse(message)
            parsed if parsed.fetch("event") == "sign.refused"
          rescue JSON::ParserError
            nil
          end

        assert_equal 1, refusal_events.length

        data = refusal_events.fetch(0).fetch("data")

        assert_equal "retryable", data.fetch("refusal_class")
        assert_equal "sentry_blocked", data.fetch("reason_code")
        assert_equal surface.to_s, data.fetch("surface")
        assert_no_match(/entry_ref/, refusal_events.fetch(0).to_json)
      end
    end
  end
end
