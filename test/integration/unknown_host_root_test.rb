# typed: false
# frozen_string_literal: true

require "test_helper"

# Host Authorization admits more hostnames than the router serves: `config.hosts` is built from
# both the PUBLIC_* and PRIVATE_* families plus the development tunnel aliases, while a surface is
# only reachable if some `constraints(host:)` block claims it.
#
# For a hostname in that gap, Rails' development-only `get "/" => "rails/welcome#index"` answered
# 200 while every other path returned 404. Anything checking status codes read the surface as
# alive. A Core hostname sat in exactly that state, and the welcome page is what made it look
# healthy while it served nothing.
class UnknownHostRootTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  # No Palm corporate route or host-authorization entry exists; this remains useful for confirming
  # that an unclaimed product hostname cannot reach the framework welcome page.
  UNSERVED_HOST = "palm-jp.umaxica.com"

  test "a host no surface claims does not answer 200 on root" do
    host! UNSERVED_HOST

    get "/"

    assert_response :not_found
    assert_equal "unknown_host", response.parsed_body["error"]
  end

  test "the framework welcome page is unreachable" do
    recognized = Rails.application.routes.recognize_path("http://#{UNSERVED_HOST}/", method: :get)

    assert_equal "unknown_hosts", recognized[:controller]
    assert_not_equal "rails/welcome", recognized[:controller]
  end

  test "claiming root for unknown hosts does not take it from the surfaces that own one" do
    {
      ENV.fetch("PRIVATE_CORE_SERVICE_URL", "core.app.localhost") => "core/app/roots",
      ENV.fetch("PRIVATE_BASE_SERVICE_URL", "base.app.localhost") => "base/app/roots",
      ENV.fetch("PRIVATE_DOCS_SERVICE_URL", "docs.app.localhost") => "docs/app/roots",
    }.each do |host, controller|
      recognized = Rails.application.routes.recognize_path("http://#{host}/", method: :get)

      assert_equal controller, recognized[:controller],
                   "#{host} lost its own root to the unknown-host fallback"
    end
  end

  # Host Authorization is not enabled in the test environment, so this reaches routing and lands
  # on the same fallback. In development and production the same request is refused earlier, with
  # 403, because the hostname is not in `config.hosts` at all. Either way it is not a 200.
  test "an arbitrary host reaches no surface" do
    host! "nonsense.invalid"

    get "/"

    assert_response :not_found
    assert_equal "unknown_host", response.parsed_body["error"]
  end
end
