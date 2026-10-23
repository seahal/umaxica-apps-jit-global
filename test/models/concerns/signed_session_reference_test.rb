# typed: false
# frozen_string_literal: true

require "test_helper"

class SignedSessionReferenceTest < ActiveSupport::TestCase
  setup do
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    OperatorStatus.find_or_create_by!(id: OperatorStatus::NOTHING)
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)

    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, public_id: PublicId.generate,
      status_id: ClientStatus::NOTHING,
    )
    @staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, staff_status: OperatorStatus.find(OperatorStatus::NOTHING))

    @user_token = ClientToken.create!(authentication_epoch: 0, user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @staff_token = OperatorToken.create!(authentication_epoch: 0, staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  test "signed refs round-trip and blank refs return nil" do
    assert_nil ClientToken.find_from_signed_ref(nil)
    assert_nil ClientToken.find_from_signed_ref("")

    assert_equal @user_token.id, ClientToken.find_from_signed_ref(@user_token.signed_ref)&.id
    assert_equal @staff_token.id, OperatorToken.find_from_signed_ref(@staff_token.signed_ref)&.id
  end

  test "find_from_signed_ref returns nil for invalid signature" do
    assert_nil ClientToken.find_from_signed_ref("invalid-signed-ref")
  end

  test "find_from_signed_refs returns empty array for blank and invalid refs" do
    assert_empty ClientToken.find_from_signed_refs(nil)
    assert_empty ClientToken.find_from_signed_refs(["", nil])
    assert_empty ClientToken.find_from_signed_refs(["invalid-signed-ref"])
  end

  test "find_from_signed_refs returns matching tokens for valid refs" do
    second_token = ClientToken.create!(authentication_epoch: 0, user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    tokens = ClientToken.find_from_signed_refs([@user_token.signed_ref, second_token.signed_ref])

    assert_equal [@user_token.id, second_token.id].sort, tokens.map(&:id).sort
  end

  test "find_from_signed_ref rejects signed refs when id and public id do not match one token" do
    mismatched_ref =
      Rails.application.message_verifier(:session_ref).generate(
        { id: @user_token.id, pid: @staff_token.public_id },
        expires_in: SignedSessionReference::REF_EXPIRES_IN,
      )

    assert_nil ClientToken.find_from_signed_ref(mismatched_ref)
  end
end
