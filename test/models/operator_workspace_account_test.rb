# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_workspace_accounts
# Database name: org_zenith
#
#  id            :bigint           not null, primary key
#  lock_version  :integer          default(0), not null
#  moniker       :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  department_id :bigint
#  public_id     :string           not null
#  staff_id      :bigint           not null
#  status_id     :bigint           default(2), not null
#
# Indexes
#
#  index_operator_workspace_accounts_on_department_id  (department_id)
#  index_operator_workspace_accounts_on_public_id      (public_id) UNIQUE
#  index_operator_workspace_accounts_on_staff_id       (staff_id)
#  index_operator_workspace_accounts_on_status_id      (status_id)
#
require "test_helper"

class OperatorWorkspaceAccountTest < ActiveSupport::TestCase
  fixtures :department_statuses, :operator_workspace_account_statuses, :operators, :organizations

  test "operators association disables joins" do
    association = OperatorWorkspaceAccount.reflect_on_association(:operators)

    assert_equal :has_many, association.macro
    assert association.options[:disable_joins]
  end

  test "operators loads linked operators through memberships without joining tables" do
    department =
      Department.create!(
        name: "Workspace Department",
        department_status: department_statuses(:active),
        workspace: organizations(:one),
      )
    account = OperatorWorkspaceAccount.create!(staff: operators(:one), department: department)
    OperatorWorkspaceAccountMembership.create!(
      operator_workspace_account: account,
      staff: operators(:two),
    )

    capture_sql =
      lambda do
        queries = []
        subscription =
          ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
            next if payload[:name] == "SCHEMA"
            next if payload[:cached]

            queries << payload[:sql].to_s
          end

        records = account.reload.operators.to_a

        [records, queries]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscription) if subscription
      end

    records, queries = capture_sql.call
    selects = queries.grep(/^SELECT/i)

    assert_equal [operators(:two)], records
    assert selects.any? { |sql| sql.include?("operator_workspace_account_memberships") }
    assert selects.any? { |sql| sql.include?("operators") }
    assert_not selects.any? { |sql|
      sql.match?(/JOIN/i) && sql.include?("operator_workspace_account_memberships") && sql.include?("operators")
    }
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorWorkspaceAccount)
  end
end
