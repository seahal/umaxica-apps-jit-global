# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_passkey_statuses
# Database name: org_zenith
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPasskeyStatusTest < ActiveSupport::TestCase
  fixtures :operator_passkey_statuses

  test "constants are defined" do
    assert_equal 1, OperatorPasskeyStatus::ACTIVE
    assert_equal 2, OperatorPasskeyStatus::REVOKED
  end
end
