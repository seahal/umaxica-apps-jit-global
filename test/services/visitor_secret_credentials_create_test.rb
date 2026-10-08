# typed: false
# frozen_string_literal: true

require "test_helper"

class VisitorSecretCredentialsCreateTest < ActiveSupport::TestCase
  setup do
    ensure_visitor_reference_records!
    @visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor: @visitor,
      address: "visitor-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
  end

  test "creates an active secret credential with a generated raw secret" do
    result = VisitorSecretCredentialsCreate.call(
      actor: @visitor,
      visitor: @visitor,
      params: { name: "api-key-1", enabled: true },
    )

    assert_predicate result.secret_credential, :persisted?
    assert_predicate result.raw_secret_credential, :present?
    assert_equal "api-key-1", result.secret_credential.name
    assert_equal VisitorSecretCredential.status_id_for(:active),
                 result.secret_credential.visitor_secret_credential_status_id
  end

  test "creates a revoked secret credential when enabled is false" do
    result = VisitorSecretCredentialsCreate.call(
      actor: @visitor,
      visitor: @visitor,
      params: { name: "disabled-key", enabled: false },
    )

    assert_equal VisitorSecretCredential.status_id_for(:revoked),
                 result.secret_credential.visitor_secret_credential_status_id
  end

  test "uses the provided raw secret credential and strips the name" do
    provided = VisitorSecretCredential.generate_raw_secret_credential

    result = VisitorSecretCredentialsCreate.call(
      actor: @visitor,
      visitor: @visitor,
      params: { name: "  spaced-name  ", enabled: "1" },
      raw_secret_credential: provided,
    )

    assert_equal provided, result.raw_secret_credential
    assert_equal "spaced-name", result.secret_credential.name
    assert_equal VisitorSecretCredential.status_id_for(:active),
                 result.secret_credential.visitor_secret_credential_status_id
  end

  private

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::REVOKED)
    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
  end
end
