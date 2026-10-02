# typed: false
# frozen_string_literal: true

require "test_helper"

# A Jump configuration failure is a configuration error. The Base sign start is the handoff to Auth
# that goes through Jump, and it must never absorb a missing signing key or an invalid issuer
# identity by downgrading to a same-host redirect. (A protected Base page no longer hands off at all:
# it points at Base's own GET /sign.)
class JumpConfigurationFailClosedTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup { @original_base_service_url = ENV.fetch("PUBLIC_BASE_SERVICE_URL", nil) }

  test "a sign-in handoff succeeds through Jump when configuration is valid" do
    host! "www.umaxica.app"
    https!
    post base_app_sign_show_path(ri: "jp")

    assert_response :redirect
    assert_equal "jump.umaxica.net", URI.parse(response.location).host
  end

  test "a missing Jump signing key raises instead of downgrading to a same-host redirect" do
    host! "www.umaxica.app"
    https!

    JumpRtKeyring.stub(:private_key, nil) do
      assert_raises(JumpRtConfigurationError) { post base_app_sign_show_path(ri: "jp") }
    end
  end

  test "an invalid issuer identity raises instead of downgrading to a same-host redirect" do
    host!("www.umaxica.app")
    https!

    ENV["PUBLIC_BASE_SERVICE_URL"] = "base.app.localhost"
    assert_raises(JumpRtConfigurationError) { post(base_app_sign_show_path(ri: "jp")) }
  ensure
    ENV["PUBLIC_BASE_SERVICE_URL"] = @original_base_service_url
  end

  test "development Rails signs with its canonical issuer origin instead of rejecting it" do
    host! "www.umaxica.app"
    https!

    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      post base_app_sign_show_path(ri: "jp")
    end

    assert_response :redirect
    location = URI.parse(response.location)
    rt = Rack::Utils.parse_query(location.query).fetch("rt")

    assert_equal "jump.umaxica.net", location.host
    assert_equal "https://www.umaxica.app", JWT.decode(rt, nil, false).first.fetch("iss")
  end
end
