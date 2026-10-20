# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_email_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ClientEmailStatusTest < ActiveSupport::TestCase
  test "has many client_emails" do
    assert ClientEmailStatus.reflect_on_association(:client_emails)
  end

  test "status constants are defined" do
    assert_equal 1, ClientEmailStatus::UNVERIFIED
    assert_equal 2, ClientEmailStatus::VERIFIED
    assert_equal 3, ClientEmailStatus::SUSPENDED
    assert_equal 4, ClientEmailStatus::DELETED
    assert_equal 5, ClientEmailStatus::NOTHING
    assert_equal 6, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
    assert_equal 7, ClientEmailStatus::VERIFIED_WITH_SIGN_UP
  end

  test "ensure_defaults restores missing fixed status rows" do
    ClientEmailStatus.find(ClientEmailStatus::DELETED).delete
    ClientEmailStatus.clear_fixed_id_seed_cache!

    ClientEmailStatus.ensure_defaults!

    assert ClientEmailStatus.exists?(ClientEmailStatus::DELETED)
  end

  test "restrict_with_error prevents deletion when emails exist" do
    status = ClientEmailStatus.find(ClientEmailStatus::VERIFIED)
    # Create a user identity email with this status
    user = Client.find_by!(public_id: "one_idxxxxxxxxxxxxxxx")
    ClientEmail.create!(
      id: SecureRandom.uuid,
      address: "test@example.com",
      user_id: user.id,
      user_email_status_id: status.id,
    )

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      status.destroy!
    end
  end
end
