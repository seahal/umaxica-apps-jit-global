# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientTotpCredentialSlotStatusPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "only active and inactive TOTP credentials consume an enrollment slot" do
    assert_equal [ClientTotpCredentialStatus::ACTIVE, ClientTotpCredentialStatus::INACTIVE],
                 ClientTotpCredential.slot_consuming_status_ids
    assert_not_includes ClientTotpCredential.slot_consuming_status_ids, ClientTotpCredentialStatus::REVOKED
    assert_not_includes ClientTotpCredential.slot_consuming_status_ids, ClientTotpCredentialStatus::DELETED
  end
end
