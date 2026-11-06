# frozen_string_literal: true

require "test_helper"
require_relative "../../../../../support/rp_cell_session_helper"

# O-11 leaves ORG contact-registration writes unavailable until the RP owner API contract is ready.
class Base::Org::Identity::Telephones::RegistrationRateLimitTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  include ActiveJob::TestHelper
  include RpCellSessionHelper

  test "ORG telephone writes refuse the RP cell before creating a candidate or sending a code" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: actor,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    host!(ENV.fetch("PUBLIC_BASE_STAFF_URL"))
    https!

    as_rp_cell("base-org-ww") do
      _token_response, _payload, rp_session = sign_in_rp_cell("base-org-ww", actor:, root_token: token)

      assert_instance_of RpBaseOrgSession, rp_session

      before = [OperatorTelephone.count, OperatorTelephoneCeremonyTransaction.count, enqueued_jobs.size]

      post base_org_identity_telephones_path(ri: "jp"),
           params: { staff_telephone: { raw_number: "+15558675332" } }

      assert_response :service_unavailable

      post base_org_identity_telephones_registration_path(ri: "jp"),
           params: { staff_telephone: { raw_number: "+15558675332" } }

      assert_response :service_unavailable

      patch base_org_identity_telephones_registration_path(ri: "jp"),
            params: { staff_telephone: { pass_code: "123456" } }

      assert_response :service_unavailable

      assert_equal before, [OperatorTelephone.count, OperatorTelephoneCeremonyTransaction.count, enqueued_jobs.size]
    end
  end
end
