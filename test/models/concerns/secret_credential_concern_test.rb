# typed: false
# frozen_string_literal: true

require "test_helper"

class SecretCredentialConcernTest < ActiveSupport::TestCase
  fixtures :visitors, :visitor_statuses

  class MinimalSecret
    include ActiveModel::Validations

    def self.validates(*) = nil

    def self.has_secure_password(*) = nil

    include SecretCredential
  end

  setup do
    @visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    VisitorSecretCredentialStatus::DEFAULTS.each do |id|
      VisitorSecretCredentialStatus.find_or_create_by!(id: id)
    end
    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
  end

  test "issue! creates a new record with raw secret_credential" do
    @visitor.visitor_emails.create!(
      address: "legacy-secret-#{SecureRandom.hex(8)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    record, raw = VisitorSecretCredential.issue!(
      name: "Test Secret", visitor: @visitor, visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
    )

    assert_instance_of VisitorSecretCredential, record
    assert_predicate record, :persisted?
    assert_equal 32, raw.length
    assert_equal VisitorSecretCredentialStatus::ACTIVE, record.visitor_secret_credential_status_id
  end

  test "status predicates" do
    record = VisitorSecretCredential.new(visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE)

    assert_predicate record, :active?
    record.visitor_secret_credential_status_id = VisitorSecretCredentialStatus::USED

    assert_predicate record, :used?
    record.visitor_secret_credential_status_id = VisitorSecretCredentialStatus::REVOKED

    assert_predicate record, :revoked?
    record.visitor_secret_credential_status_id = VisitorSecretCredentialStatus::EXPIRED

    assert_predicate record, :expired?
    record.visitor_secret_credential_status_id = VisitorSecretCredentialStatus::DELETED

    assert_predicate record, :deleted?
  end

  test "base secret_credential class requires status hooks" do
    assert_raises(NotImplementedError) { MinimalSecret.identity_secret_credential_status_class }
    assert_raises(NotImplementedError) { MinimalSecret.identity_secret_credential_status_id_column }
  end

  test "base secret_credential class reports unsupported optional columns" do
    assert_not MinimalSecret.supports_uses_remaining?
    assert_not MinimalSecret.supports_expiration?
  end

  test "status_id_for raises for unknown status class" do
    MinimalSecret.stub(:identity_secret_credential_status_class, Class.new) do
      assert_raises(KeyError) { MinimalSecret.status_id_for(:active) }
    end
  end
end
