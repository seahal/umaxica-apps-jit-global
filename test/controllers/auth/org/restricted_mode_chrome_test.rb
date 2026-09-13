# typed: false
# frozen_string_literal: true

require "test_helper"

# The Restricted Mode indicator is published by the shared surface chrome, not
# by any page.
#
# That is the requirement, not an implementation detail: an operator in an
# Emergency session must see the indicator for the whole life of that session,
# and no screen may be able to drop it. Since no screen supplies it, no screen
# can forget it -- which is what the "another authenticated page" test below
# demonstrates.
class Auth::Org::RestrictedModeChromeTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_tokens

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! @host
    @staff = operators(:one)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    @token = operator_tokens(:one)
  end

  def headers_for(context)
    @token.update!(authentication_context: context)

    as_staff_headers(@staff, host: @host, session_public_id: @token.reload.public_id)
  end

  test "a normal session renders no restricted mode indicator" do
    get auth_org_dashboard_url(ri: "jp"), headers: headers_for(nil)

    assert_response :success
    assert_nil inertia_props.fetch("chrome").fetch("restricted_mode")
  end

  test "an emergency session renders the restricted mode indicator in the shared chrome" do
    get auth_org_dashboard_url(ri: "jp"), headers: headers_for("emergency")

    assert_response :success
    restricted = inertia_props.fetch("chrome").fetch("restricted_mode")

    assert_equal I18n.t("layouts.shared.restricted_mode.label"), restricted.fetch("label")
    assert_equal I18n.t("layouts.shared.restricted_mode.description"), restricted.fetch("description")
  end

  # The only offered way back to a normal session is to end this one. There is
  # no "leave restricted mode" operation, because there is no in-session
  # transition for such a control to perform.
  test "the indicator offers sign-out and nothing that claims to switch mode in place" do
    get auth_org_dashboard_url(ri: "jp"), headers: headers_for("emergency")

    restricted = inertia_props.fetch("chrome").fetch("restricted_mode")

    assert_equal I18n.t("layouts.shared.restricted_mode.sign_out"), restricted.dig("sign_out", "label")
    assert_equal new_auth_org_sign_out_path(ri: "jp"), restricted.dig("sign_out", "href")
    assert_no_match(/解除/, restricted.to_s)
  end

  # No page can omit the indicator because no page produces it. If a controller
  # or page component ever started publishing its own, that guarantee would be
  # gone and the indicator could go missing from one screen.
  test "only the shared chrome produces the restricted mode indicator" do
    producers =
      Rails.root.glob("app/controllers/**/*.rb").select do |path|
        next false if path.to_s.end_with?("app/controllers/concerns/surface_chrome.rb")

        path.read.match?(/^\s*restricted_mode:/)
      end

    assert_empty producers.map { |path| path.relative_path_from(Rails.root).to_s },
                 "Restricted Mode is session state published once by SurfaceChrome, not page props"

    page_producers = Rails.root.glob("src/pages/**/*.tsx").select { |path| path.read.include?("restricted_mode:") }

    assert_empty page_producers.map { |path| path.relative_path_from(Rails.root).to_s }
  end
end
