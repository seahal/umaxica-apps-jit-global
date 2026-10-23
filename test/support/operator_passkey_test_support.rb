# frozen_string_literal: true

# D-132: an ADVANCED Operator uses ORG Base only while holding two active Passkeys. Tests about other
# ORG behavior give their Operator that state with this helper.
module OperatorPasskeyTestSupport
  module_function

  def give_two_active_passkeys!(operator)
    (2 - OperatorPasskey.where(staff_id: operator.id, status_id: OperatorPasskeyStatus::ACTIVE).count).times do
      OperatorPasskey.create!(
        staff: operator, webauthn_id: SecureRandom.urlsafe_base64(32), external_id: SecureRandom.uuid,
        public_key: "test-public-key", sign_count: 0, description: "D-132 test passkey",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    operator.reload
  end
end
