# frozen_string_literal: true

require "test_helper"

class JumpDirectedHandoffsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Auth direct ceremony entry and sign out use same TLD public Base through Jump" do
    %w(app com org).each do |tld|
      host! "auth.umaxica.#{tld}"
      https!
      %w(/sign/in /sign/out).each do |path|
        get path, params: { ri: "us" }

        assert_response :see_other
        location = URI.parse(response.location)

        assert_equal "jump.umaxica.net", location.host
        token = Rack::Utils.parse_nested_query(location.query).fetch("rt")
        payload, = JWT.decode(token, nil, false)
        target = URI.parse(payload.fetch("url"))

        assert_equal "https://auth.umaxica.#{tld}", payload.fetch("iss")
        assert_equal "www.umaxica.#{tld}", target.host
        assert_equal "https", target.scheme
        assert_equal "us", Rack::Utils.parse_nested_query(target.query).fetch("ri")
      end
    end
  end

  test "Core and Warp sign entry POST uses Jump with public Base even on the same site" do
    %w(app com org).each do |tld|
      ["jp.umaxica.#{tld}", "www-jp.umaxica.#{tld}"].each do |host|
        host! host
        https!
        post "/sign", params: { ri: "jp" }, headers: {
          "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
        }

        assert_response :redirect
        gateway = URI.parse(response.location)

        assert_equal "jump.umaxica.net", gateway.host
        rt = Rack::Utils.parse_nested_query(gateway.query).fetch("rt")
        payload, = JWT.decode(rt, nil, false)
        target = URI.parse(payload.fetch("url"))
        query = Rack::Utils.parse_nested_query(target.query)

        assert_equal "https://#{host}", payload.fetch("iss")
        assert_equal "www.umaxica.#{tld}", target.host
        assert_equal "https", target.scheme
        assert_equal "/oauth/authorize", target.path
        assert_equal "https://#{host}/sign/callback", query.fetch("redirect_uri")
        assert_equal "S256", query.fetch("code_challenge_method")
        assert_predicate query.fetch("state"), :present?
        assert_predicate query.fetch("nonce"), :present?
      end
    end
  end

  test "Edit keeps its existing same-site authorization admission pending separate RP review" do
    host! "edit.umaxica.org"
    https!
    get "/publishing/info/org/entries", params: { ri: "jp" }

    assert_response :found
    target = URI.parse(response.location)
    assert_equal "https", target.scheme
    assert_equal "www.umaxica.org", target.host
    assert_equal "/oauth/authorize", target.path
    assert_equal "edit-org", Rack::Utils.parse_nested_query(target.query).fetch("client_id")
  end

end
