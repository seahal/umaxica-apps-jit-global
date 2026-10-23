# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_accounts
# Database name: com_zenith
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  visitor_id :bigint           not null
#
# Indexes
#
#  index_visitor_accounts_on_public_id   (public_id) UNIQUE
#  index_visitor_accounts_on_visitor_id  (visitor_id) UNIQUE
#
require "test_helper"

class VisitorAccountTest < ActiveSupport::TestCase
  setup do
    VisitorStatus.ensure_defaults!
    VisitorVisibility.ensure_defaults!
  end

  test "creates one visitor scoped client account for a visitor" do
    visitor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    account = VisitorAccount.create!(visitor: visitor)

    assert_predicate account.public_id, :present?
    assert_equal ComRpRecord.connection_db_config.name, account.class.connection_db_config.name
    assert_equal account, visitor.reload.rp_account
  end

  test "requires a visitor" do
    account = VisitorAccount.new

    assert_not account.valid?
    assert account.errors.of_kind?(:visitor, :blank)
  end

  test "allows only one account per visitor" do
    visitor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    VisitorAccount.create!(visitor: visitor)

    duplicate = VisitorAccount.new(visitor: visitor)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:visitor_id, :taken)
  end

  test "requires unique generated public id" do
    account = VisitorAccount.create!(visitor: Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL))

    duplicate = VisitorAccount.new(
      visitor: Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL),
      public_id: account.public_id,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:public_id, :taken)
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::VisitorAccount)
  end
end
