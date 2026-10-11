# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Dev::RootsControllerTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  test "renders the developer root page on the developer host" do
    host! ENV.fetch("PRIVATE_BASE_DEVELOPER_URL", "base.dev.localhost")

    get base_developer_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "#{BRAND} (DEV)"
    assert_select "h1", "Base Dev"
  end
end
