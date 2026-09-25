# typed: false
# frozen_string_literal: true

require "test_helper"

class SecretCredentialConcernTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  class DummySecret < AppPrincipalRecord
    self.table_name = "client_secret_credentials"
    self.belongs_to_required_by_default = false
    include PublicId
    include Retainable
    include SecretCredential

    belongs_to :user, class_name: "Client"
    alias_attribute :user_secret_status_id, :user_identity_secret_status_id

    def self.identity_secret_credential_status_class
      ClientSecretCredentialStatus
    end

    def self.identity_secret_credential_status_id_column
      :user_identity_secret_status_id
    end
  end

  class MinimalSecret
    include ActiveModel::Validations

    def self.validates(*) = nil

    def self.has_secure_password(*) = nil

    include SecretCredential
  end

  setup do
    @user = Client.find_by!(public_id: "one_id")
    # Ensure statuses exist
    ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::ACTIVE)
    ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::USED)
    ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::EXPIRED)
    ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::REVOKED)
    # Ensure kinds exist
    ClientSecretCredentialKind.find_or_create_by!(id: ClientSecretCredentialKind::LOGIN)
  end

  test "issue! creates a new record with raw secret_credential" do
    record, raw = DummySecret.issue!(name: "Test Secret", user: @user, user_secret_kind_id: ClientSecretCredentialKind::LOGIN)

    assert_instance_of DummySecret, record
    assert_predicate record, :persisted?
    assert_equal 32, raw.length
    assert_equal ClientSecretCredentialStatus::ACTIVE, record.user_secret_status_id
  end

  test "status predicates" do
    record = DummySecret.new(user_secret_status_id: ClientSecretCredentialStatus::ACTIVE)

    assert_predicate record, :active?
    record.user_secret_status_id = ClientSecretCredentialStatus::USED

    assert_predicate record, :used?
    record.user_secret_status_id = ClientSecretCredentialStatus::REVOKED

    assert_predicate record, :revoked?
    record.user_secret_status_id = ClientSecretCredentialStatus::EXPIRED

    assert_predicate record, :expired?
    record.user_secret_status_id = ClientSecretCredentialStatus::DELETED

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
