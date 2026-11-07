# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::IdentityEntryMfaResetLinkTest < ActionDispatch::IntegrationTest
  fixtures :operators

  test "the RP identity entry links to the available MFA reset page" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = operators(:one)
    operator.update!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    headers = as_staff_headers(operator, host:)

    get base_org_identity_url(ri: "jp", host: host), headers: headers

    assert_response :success
    label = I18n.t("base.org.identity.mfa_reset", locale: :ja)
    link =
      inertia_props.fetch("sections")
        .flat_map { |section| section.fetch("items") }
        .find { |item| item.fetch("label") == label }

    assert_equal base_org_identity_mfa_reset_path(ri: "jp"), link.fetch("href")

    get link.fetch("href"), headers: headers

    assert_response :success
    assert_equal "base/org/identity/mfa/resets/show", inertia_component
  end
end
