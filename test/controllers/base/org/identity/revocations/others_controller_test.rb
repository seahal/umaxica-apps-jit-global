# typed: false
# frozen_string_literal: true

require "test_helper"

# Staff-surface "revoke every other session" HTTP path. The shared revoker is
# already covered at the operation layer; this test drives the org controller
# through the authenticated staff request so the HTTP action itself is
# exercised, including the destroy alias.
class Base::Org::Identity::Revocations::OthersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host
    host! @host
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::NOTHING)
    OperatorTokenBindingMethod.ensure_defaults!
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
  end

  test "destroy revokes every other staff session and keeps the current one" do
    headers = as_staff_headers(@operator, host: @host)
    current = authentication_harness_latest_token(@operator)
    other = OperatorToken.create!(
      staff: @operator,
      staff_token_status_id: OperatorTokenStatus::NOTHING,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      public_id: "org_other_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    other.update!(created_at: 1.hour.ago)

    delete base_org_identity_other_sessions_url(ri: "jp", host: @host), headers: headers

    assert_response :see_other
    assert_redirected_to base_org_sessions_path(ri: "jp")
    assert_not_predicate other.reload, :currently_usable?
    assert_predicate current.reload, :currently_usable?
  end
end
