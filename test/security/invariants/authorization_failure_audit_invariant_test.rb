# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # An authorization denial is a security event of record: besides refusing the request, it
    # must leave an AUTHORIZATION_FAILED chronicle for the actor that was refused.
    class AuthorizationFailureAuditInvariantTest < ActionDispatch::IntegrationTest
      test "an operator refused by a staff policy is answered 403 and recorded as an authorization failure" do
        host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
        operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
        OperatorToken.create!(staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

        before =
          ChronicleRecord.connected_to(role: :writing) do
            OperatorChronicle.where(event_id: OperatorChronicleEvent::AUTHORIZATION_FAILED).count
          end

        get base_org_system_index_url(ri: "jp", host: host),
            headers: as_staff_headers(operator, host: host, headers: { "Accept" => "application/json" })

        assert_response :forbidden
        assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
        audits =
          ChronicleRecord.connected_to(role: :writing) do
            OperatorChronicle.where(event_id: OperatorChronicleEvent::AUTHORIZATION_FAILED).order(:occurred_at).to_a
          end

        assert_equal before + 1, audits.size
        assert_equal operator.id.to_s, audits.last.subject_id.to_s
      end
    end
  end
end
