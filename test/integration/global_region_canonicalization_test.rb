# frozen_string_literal: true

require "test_helper"

class GlobalRegionCanonicalizationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Global browser roots canonicalize missing region on GET and HEAD" do
    %w(base.app.localhost base.com.localhost base.org.localhost
       auth.app.localhost auth.com.localhost auth.org.localhost
       visa.app.localhost visa.com.localhost visa.org.localhost
       tech.org.localhost edit.org.localhost).each do |host|
      host! host
      get "/", params: { lx: "en", ct: "dr", marker: "retained" }

      assert_response :found
      destination = URI.parse(response.location)

      assert_equal host, destination.host
      assert_equal "/", destination.path
      assert_equal(
        { "ri" => "jp", "lx" => "en", "ct" => "dr", "marker" => "retained" },
        Rack::Utils.parse_nested_query(destination.query),
      )

      head "/"

      assert_response :found
      assert_empty response.body
      assert_equal "jp", Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("ri")
    end
  end

  test "Base Auth and Visa roots normalize invalid region inputs and accept both regions" do
    %w(base.app.localhost base.com.localhost base.org.localhost
       auth.app.localhost auth.com.localhost auth.org.localhost
       visa.app.localhost visa.com.localhost visa.org.localhost).each do |host|
      host! host
      ["", "xx", "j", "jpp", "0", ["jp"], { value: "jp" }].each do |invalid|
        get "/", params: { ri: invalid }

        assert_response :found
        assert_equal "jp", Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("ri")
      end
      %w(jp us).each do |region|
        get "/", params: { ri: region }

        assert_response :ok
        assert_nil response.location
      end
    end
  end

  test "Visa protocol metadata does not canonicalize missing region" do
    %w(visa.app.localhost visa.com.localhost visa.org.localhost).each do |host|
      host! host
      get "/.well-known/openid-configuration"

      assert_response :ok
      assert_nil response.location
      assert_equal "application/json", response.media_type
    end
  end
end
