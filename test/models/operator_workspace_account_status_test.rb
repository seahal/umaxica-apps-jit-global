# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_workspace_account_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorWorkspaceAccountStatusTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 1, OperatorWorkspaceAccountStatus::ACTIVE
    assert_equal 2, OperatorWorkspaceAccountStatus::NOTHING
  end
end
