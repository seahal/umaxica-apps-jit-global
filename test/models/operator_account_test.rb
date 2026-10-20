# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_accounts
# Database name: org_zenith
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_operator_accounts_on_public_id  (public_id) UNIQUE
#  index_operator_accounts_on_staff_id   (staff_id) UNIQUE
#
require "test_helper"

class OperatorAccountTest < ActiveSupport::TestCase
  test "creates one account for a staff" do
    account = OperatorAccount.create!(staff: operators(:one))

    assert_predicate account.public_id, :present?
    assert_equal OrgRpRecord.connection_db_config.name, account.class.connection_db_config.name
    assert_equal account, operators(:one).reload.rp_account
  end

  test "requires a staff" do
    account = OperatorAccount.new

    assert_not account.valid?
    assert account.errors.of_kind?(:staff, :blank)
  end

  test "allows only one account per staff" do
    OperatorAccount.create!(staff: operators(:two))

    duplicate = OperatorAccount.new(staff: operators(:two))

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:staff_id, :taken)
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorAccount)
  end
end
