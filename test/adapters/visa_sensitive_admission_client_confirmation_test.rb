# typed: false
# frozen_string_literal: true

require "test_helper"

class VisaSensitiveAdmissionClientConfirmationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "browser confirmation sends the bound admission to the correct Visa surface" do
    [
      %w(app client base-app-ww),
      %w(org operator base-org-ww),
    ].each do |surface, resource_type, client_id|
      endpoint = URI.parse(
        OutboundHttp::LocalBackChannel.url(
          "#{OidcIssuer.for_resource_type(resource_type)}/api/v0/sensitive_admission_confirmation",
        ),
      )
      request_facts = []
      assertion_facts = []
      stubs =
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post(endpoint.path) do |environment|
            request_facts << [environment.url.to_s, environment.request_headers, environment.body]
            [204, {}, ""]
          end
        end
      connection =
        Faraday.new(url: endpoint.origin) do |builder|
          builder.request(:url_encoded)
          builder.adapter(:test, stubs)
        end

      issue_assertion =
        lambda do |**claims|
          assertion_facts << [claims.fetch(:client_id), claims.fetch(:token_url)]
          "test-client-assertion"
        end
      OidcClientAssertionJwt.stub(:issue, issue_assertion) do
        OutboundHttp::Connection.stub(:build, connection) do
          TestSupport::OutboundHttpGuard.allow do
            result = VisaSensitiveAdmissionClient.new(surface:, access_token: "test-access-token").confirm_browser!(
              admission_ref: "admission-reference",
              rp_session_ref: "rp-session-reference",
              browser_binding_digest: "a" * 64,
            )

            assert_predicate result, :ok?
          end
        end
      end

      assert_equal 1, request_facts.length
      assert_equal [[client_id, endpoint.to_s]], assertion_facts
      request_url, headers, body = request_facts.fetch(0)

      assert_equal endpoint.to_s, request_url
      assert_equal "Bearer test-access-token", headers.fetch("Authorization")
      assert_equal "test-client-assertion", headers.fetch("X-Client-Assertion")
      assert_equal(
        {
          "admission_ref" => "admission-reference",
          "rp_session_ref" => "rp-session-reference",
          "browser_binding_digest" => "a" * 64,
        },
        Rack::Utils.parse_nested_query(body),
      )
    end
  end

  test "a rejected confirmation is distinct from a Visa dependency failure" do
    [404, 503].each do |status|
      endpoint = URI.parse(
        OutboundHttp::LocalBackChannel.url(
          "#{OidcIssuer.for_resource_type("client")}/api/v0/sensitive_admission_confirmation",
        ),
      )
      stubs =
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post(endpoint.path) { [status, {}, ""] }
        end
      connection =
        Faraday.new(url: endpoint.origin) do |builder|
          builder.request(:url_encoded)
          builder.adapter(:test, stubs)
        end

      OidcClientAssertionJwt.stub(:issue, "test-client-assertion") do
        OutboundHttp::Connection.stub(:build, connection) do
          TestSupport::OutboundHttpGuard.allow do
            result = VisaSensitiveAdmissionClient.new(surface: "app", access_token: "test-access-token")
              .confirm_browser!(
                admission_ref: "admission-reference",
                rp_session_ref: "rp-session-reference",
                browser_binding_digest: "b" * 64,
              )

            assert_equal((status == 404) ? :refused : :dependency, result.status)
          end
        end
      end
    end
  end

  test "confirmation cannot be dispatched without an access token" do
    result = VisaSensitiveAdmissionClient.new(surface: "app", access_token: " ").confirm_browser!(
      admission_ref: "admission-reference",
      rp_session_ref: "rp-session-reference",
      browser_binding_digest: "c" * 64,
    )

    assert_equal :unauthorized, result.status
  end
end
