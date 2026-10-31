# frozen_string_literal: true

require "test_helper"

class DomainAuthorityProtocolTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Base authority lookup accepts only active actor realms" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)

    assert_equal hosts.base_service, hosts.base_for_resource_type("client")
    assert_equal hosts.base_staff, hosts.base_for_resource_type("operator")
    assert_equal hosts.base_staff, hosts.base_for_resource_type("staff")
    [nil, "", false, "unknown", "visitor", "customer"].each do |resource_type|
      assert_raises(ArgumentError) { hosts.base_for_resource_type(resource_type) }
    end
  end

  test "identity authority clients reject retired and unknown surfaces before making a request" do
    request = ActionDispatch::TestRequest.create
    %w(app org).each do |surface|
      assert_instance_of AvatarAuthorityClient,
                         AvatarAuthorityClient.new(surface: surface, access_token: "token", persona: "person")
      assert_instance_of MembershipAuthorityClient,
                         MembershipAuthorityClient.new(surface: surface, access_token: "token", persona: "person")
    end
    ["com", "", "unknown", nil].each do |surface|
      assert_raises(KeyError) { AvatarAuthorityClient.new(surface: surface, access_token: "token", persona: "person") }
      assert_raises(KeyError) do
        MembershipAuthorityClient.new(surface: surface, access_token: "token", persona: "person")
      end
      assert_raises(KeyError) do
        OrgAdminAuthorityClient.new(surface: surface, access_token: "token", browser_request: request)
      end
    end
  end

  test "group lookup escapes the reference as one path segment and preserves owner refusals" do
    connection = Faraday.new
    reference = "../other?admin=true#fragment"
    [200, 403, 404].each do |status|
      response = Faraday::Response.new(status: status, body: { group: "synthetic" }.to_json)
      fetch =
        lambda do |uri, params, _headers|
          assert_equal "/api/v0/avatar/app/groups/#{ERB::Util.url_encode(reference)}", uri.path
          assert_nil uri.query
          assert_nil uri.fragment
          assert_equal "persona", params.fetch(:persona)
          response
        end
      OidcClientAssertionJwt.stub(:issue, "synthetic-assertion") do
        OutboundHttp::Connection.stub(:build, connection) do
          connection.stub(:get, fetch) do
            result = AvatarAuthorityClient.new(
              surface: "app", access_token: "synthetic", persona: "persona",
            ).fetch_group(reference)

            assert_equal({ 200 => :ok, 403 => :forbidden, 404 => :not_found }.fetch(status), result.status)
          end
        end
      end
    end
  end

  test "domain clients preserve owner objects and refuse non-object JSON as dependency failures" do
    browser_request = ActionDispatch::TestRequest.create
    clients = [
      -> {
        PublishingAuthorityClient.new(surface: "app", audience: "help", access_token: "synthetic").entries(page: 1)
      },
      -> { AvatarAuthorityClient.new(surface: "app", access_token: "synthetic", persona: "persona").groups },
      -> { MembershipAuthorityClient.new(surface: "app", access_token: "synthetic", persona: "persona").accounts },
      -> {
        OrgAdminAuthorityClient.new(access_token: "synthetic", browser_request: browser_request).get("/iam/grants")
      },
    ]
    connection = Faraday.new
    [{ "items" => [] }, [], nil, true, 1, "invalid-object"].each do |body|
      response = Faraday::Response.new(status: 200, body: body.to_json)
      clients.each do |call|
        OidcClientAssertionJwt.stub(:issue, "synthetic-assertion") do
          OutboundHttp::Connection.stub(:build, connection) do
            connection.stub(:get, response) do
              result = call.call
              if body.is_a?(Hash)
                assert_predicate result, :ok?
                assert_equal body, result.data
              else
                assert_equal :dependency, result.status
                assert_nil result.data
              end
            end
          end
        end
      end
    end
  end

  test "Tech requires an explicit boolean allow in an object and refuses other JSON shapes" do
    connection = Faraday.new
    [{ "allowed" => true }, { "allowed" => false }, { "allowed" => "true" }, {}, [], nil, true, 1].each do |body|
      response = Faraday::Response.new(status: 200, body: body.to_json)
      OidcClientAssertionJwt.stub(:issue, "synthetic-assertion") do
        OutboundHttp::Connection.stub(:build, connection) do
          connection.stub(:post, response) do
            assert_equal body == { "allowed" => true }, TechCapabilityClient.allowed?(access_token: "synthetic")
          end
        end
      end
    end
  end
end
