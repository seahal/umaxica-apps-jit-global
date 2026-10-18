# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: operator_secret_credential_kinds
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorSecretCredentialKindTest < ActiveSupport::TestCase
  test "valid kind" do
    kind = OperatorSecretCredentialKind.new(id: 99)

    assert_predicate kind, :valid?
    assert kind.save
    assert_equal 99, kind.id
  end

  test "validates uniqueness of id" do
    OperatorSecretCredentialKind.create!(id: 77)
    duplicate = OperatorSecretCredentialKind.new(id: 77)

    assert_predicate duplicate, :invalid?
    assert_predicate duplicate.errors[:id], :any?
  end

  test "constants are defined" do
    assert_equal 2, OperatorSecretCredentialKind::LOGIN
    assert_equal [2], OperatorSecretCredentialKind::ALL
  end
end
