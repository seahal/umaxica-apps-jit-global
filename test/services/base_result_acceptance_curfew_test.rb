# typed: false
# frozen_string_literal: true

require "test_helper"

# WU-06 A06-2: a result issued before the curfew is refused when Base would accept it at or after the
# curfew; the Cancel exit still validates, because it is how the attempt ends.
class BaseResultAcceptanceCurfewTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @nonce = SecureRandom.urlsafe_base64(32)
    issuance = OidcTestEntry.issue!(surface: "app", intent: "sign_in", base_browser_nonce: @nonce, base_token: nil)
    @transaction = issuance.transaction
    @binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    @binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    @binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(surface: "app", entry_ref: issuance.reference, nonce: @nonce),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_in", binding: @binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: @transaction.transaction_id,
    )
    @binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
  end

  test "acceptance before the curfew validates the owner's browser" do
    move_curfew!(1.minute)

    assert_equal @binding.id, validate!.id
  end

  test "acceptance after the curfew is refused but the Cancel exit still validates" do
    move_curfew!(-1.second)
    error = assert_raises(BaseAuthAdmissionCoordinator::Denied) { validate! }

    assert_equal "expired_admission", error.code
    assert_equal @binding.id, validate!(cancellation: true).id
  end

  private

  def move_curfew!(offset)
    @binding.update_columns(curfew_at: ClientAuthAdmissionBinding.database_now + offset)
  end

  def validate!(cancellation: false)
    BaseAuthAdmissionCoordinator.validate_result_browser_binding!(
      transaction: @transaction.reload, surface: "app", base_browser_nonce: @nonce, base_token: nil, cancellation:,
    )
  end
end
