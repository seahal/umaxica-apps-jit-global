# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # The withdrawal gate derives its redirect from the controller's surface family. An org
    # operator in the withdrawal lifecycle must land on the org withdrawal page; falling back to
    # the app page would send a staff session across the org/app trust boundary.
    class OrgWithdrawalGateInvariantTest < ActionDispatch::IntegrationTest
      fixtures :operators

      test "a closing operator on the org auth surface is redirected to the org withdrawal path" do
        org_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
        host! org_host
        operator = operators(:one)
        operator.update!(withdrawal_started_at: 1.hour.ago)

        get auth_org_settings_url(ri: "jp"), headers: as_staff_headers(operator, host: org_host)

        assert_predicate operator.reload, :closing?
        assert_response :redirect
        location = URI.parse(response.location).request_uri

        assert_equal base_org_identity_withdrawal_path(ri: "jp"), location
        assert_not_equal edit_base_app_identity_withdrawal_path(ri: "jp"), location
      end

      test "an active operator on the same route is not sent to the withdrawal path" do
        org_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
        host! org_host

        get auth_org_settings_url(ri: "jp"), headers: as_staff_headers(operators(:one), host: org_host)

        assert_response :redirect
        assert_not_equal base_org_identity_withdrawal_path(ri: "jp"), URI.parse(response.location).request_uri
      end
    end
  end
end
