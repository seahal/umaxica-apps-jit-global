# typed: false
# frozen_string_literal: true

require "test_helper"

class SecretCredentialConcernTest < ActiveSupport::TestCase
  class MinimalSecret
    include ActiveModel::Validations

    def self.validates(*) = nil

    def self.has_secure_password(*) = nil

    include SecretCredential
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
