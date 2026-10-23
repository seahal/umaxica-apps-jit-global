# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorPasskeyScopeTest < ActiveSupport::TestCase
  setup do
    @staff = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "ABCDEFGH2345WXYZ",
      status_id: OperatorStatus::NOTHING,
    )

    @active_passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "active_staff_id",
      external_id: SecureRandom.uuid,
      public_key: "pk",
      description: "Active Key",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    @inactive_passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "inactive_staff_id",
      external_id: SecureRandom.uuid,
      public_key: "pk",
      description: "Inactive Key",
      status_id: OperatorPasskeyStatus::REVOKED,
    )
  end

  test "active scope includes only active passkeys" do
    assert_includes OperatorPasskey.active, @active_passkey
    assert_not_includes OperatorPasskey.active, @inactive_passkey
  end
end
