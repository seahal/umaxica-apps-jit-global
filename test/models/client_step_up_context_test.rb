# frozen_string_literal: true

require "test_helper"

class ClientStepUpContextTest < ActiveSupport::TestCase
  test "the database rejects an ACR other than the fixed step-up class" do
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        ClientStepUpContext.insert!(
          {
            public_id: "123456789abcdefghijk",
            oidc_authorization_transaction_id: -1,
            grant_id: -1,
            bound_subject: "subject-ref",
            requested_acr: "urn:example:wrong-class",
            state_id: ClientStepUpContextState::PENDING,
            expires_at: Time.utc(2026, 11, 3, 12),
            created_at: Time.utc(2026, 11, 3, 12),
            updated_at: Time.utc(2026, 11, 3, 12),
          },
        )
      end

    assert_includes error.message, "chk_client_step_up_contexts_acr"
  end
end
