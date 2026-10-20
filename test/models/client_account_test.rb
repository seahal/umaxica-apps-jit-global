# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_accounts
# Database name: app_zenith
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_accounts_on_public_id  (public_id) UNIQUE
#  index_client_accounts_on_user_id    (user_id) UNIQUE
#
require "test_helper"

class ClientAccountTest < ActiveSupport::TestCase
  test "creates one account for a user" do
    account = ClientAccount.create!(user: clients(:one))

    assert_predicate account.public_id, :present?
    assert_equal AppRpRecord.connection_db_config.name, account.class.connection_db_config.name
    assert_equal account, clients(:one).reload.rp_account
  end

  test "requires a user" do
    account = ClientAccount.new

    assert_not account.valid?
    assert account.errors.of_kind?(:user, :blank)
  end

  test "allows only one account per user" do
    ClientAccount.create!(user: clients(:two))

    duplicate = ClientAccount.new(user: clients(:two))

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:user_id, :taken)
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ClientAccount)
  end
end
