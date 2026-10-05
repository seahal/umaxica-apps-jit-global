# typed: false
# frozen_string_literal: true

require "test_helper"

class SecretCredentialTest < ActiveSupport::TestCase
  class SecretStatus
    attr_reader :id

    ACTIVE = 1
    USED = 2
    REVOKED = 3
    EXPIRED = 4
    DELETED = 5

    def self.find(id)
      new(id)
    end

    def initialize(id)
      @id = id
    end

    def self.name
      "VisitorSecretCredentialStatus"
    end
  end

  class DummySecret
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include ActiveModel::SecurePassword

    attribute :id, :string
    attribute :name, :string
    attribute :uses_remaining, :integer
    attribute :discard_at, :datetime
    attribute :last_used_at, :datetime
    attribute :secret_credential_status_id, :integer
    attribute :password_digest, :string

    # We need to include SecretCredential LAST so it can override/use methods
    include SecretCredential

    def self.identity_secret_credential_status_class
      SecretStatus
    end

    def self.identity_secret_credential_status_id_column
      :secret_credential_status_id
    end

    # Mock DB columns for write access
    def [](key)
      if key.to_s == "secret_credential_status_id"
        attributes[key.to_s]
      else
        send(key)
      end
    end

    def []=(key, value)
      send("#{key}=", value)
    end

    # Mock ActiveRecord methods
    def save!
      true
    end

    def reload
      self
    end

    def with_lock
      yield
    end

    # Mock has_secure_password behavior without full ActiveModel::SecurePassword overhead if needed,
    # but we included it.
  end

  class MissingSecret
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include ActiveModel::SecurePassword

    attribute :password_digest, :string

    include SecretCredential
  end

  test "defines constants" do
    assert_defined_constant SecretCredential::SECRET_PASSWORD_LENGTH
  end

  test "issue! creates a new record with generated secret_credential" do
    record, raw_secret_credential = DummySecret.issue!(name: "test")

    assert_kind_of DummySecret, record
    assert_equal "test", record.name
    assert_equal 32, raw_secret_credential.length
    assert_equal DummySecret.status_id_for(:active), record[:secret_credential_status_id]
  end

  test "expire_if_needed! expires when time passed" do
    record, _ = DummySecret.issue!(name: "test", discard_at: 1.hour.ago)

    assert record.expire_if_needed!
    assert_equal DummySecret.status_id_for(:expired), record[:secret_credential_status_id]
  end

  test "raises when identity secret_credential status class is missing" do
    error = assert_raises(NotImplementedError) { MissingSecret.identity_secret_credential_status_class }

    assert_match(/define identity_secret_credential_status_class/, error.message)
  end

  test "raises when identity secret_credential status id column is missing" do
    error = assert_raises(NotImplementedError) { MissingSecret.identity_secret_credential_status_id_column }

    assert_match(/define identity_secret_credential_status_id_column/, error.message)
  end

  private

  def assert_defined_constant(constant)
    assert defined?(constant)
  end
end
