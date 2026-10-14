# typed: false
# frozen_string_literal: true

require "test_helper"

class Tech::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
  end

  test "the public landing page links to sign-in without issuing an OIDC flow" do
    get tech_org_root_path(ri: "jp")

    assert_response :success
    assert_select "h1", I18n.t("tech.org.roots.heading")
    assert_select "nav a", text: I18n.t("tech.org.roots.sign_in")
    assert_equal "/sign", URI.parse(css_select("nav a").first["href"]).path
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
  end
end
