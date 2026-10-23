# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
load Rails.root.join("lib/tasks/security_tier0.rake")

class SecurityTier0SuspiciousUserTokenReportTest < ActiveSupport::TestCase
  test "report is report-only and does not delete or revoke tokens" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_no_difference("ClientToken.count") do
      result = SecurityTier0SuspiciousUserTokenReport.call

      assert result[:report_only]
      assert_operator result[:suspicious], :>=, 1
    end

    assert ClientToken.exists?(token.id)
  end
end
