# frozen_string_literal: true

require "test_helper"

class OidcAuthorizationCancelStateTest < ActiveSupport::TestCase
  test "A13-5: cancellation returns opaque state bytes and only the protocol fields" do
    %w(client visitor operator).each do |resource_type|
      realm = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(resource_type)
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      redirect_uri = client.redirect_uris_by_realm.fetch(resource_type).first
      ["state", "a+b/%&=日本"].each do |state|
        url = OidcAuthorizeCoordinator.error_redirect_url(
          redirect_uri: redirect_uri, resource_type: resource_type, error: "access_denied", state: state,
        )
        values = Rack::Utils.parse_nested_query(URI.parse(url).query)

        assert_equal %w(error iss state), values.keys.sort, realm
        assert_equal state.bytes, values.fetch("state").bytes, realm
        assert_equal "access_denied", values.fetch("error"), realm
        assert_equal OidcIssuer.for_resource_type(resource_type), values.fetch("iss"), realm
      end
    end
  end
end
