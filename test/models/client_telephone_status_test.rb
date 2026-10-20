# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_telephone_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ClientTelephoneStatusTest < ActiveSupport::TestCase
  test "has correct constants" do
    assert_equal 0, ClientTelephoneStatus::NOTHING
    assert_equal 1, ClientTelephoneStatus::VERIFIED
    assert_equal 2, ClientTelephoneStatus::UNVERIFIED
    assert_equal 3, ClientTelephoneStatus::SUSPENDED
    assert_equal 4, ClientTelephoneStatus::DELETED
    assert_equal 5, ClientTelephoneStatus::LEGACY_NOTHING
    assert_equal 6, ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
    assert_equal 7, ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP
  end

  test "can load nothing status from db" do
    status = ClientTelephoneStatus.find(ClientTelephoneStatus::NOTHING)

    assert_equal 0, status.id
  end

  test "has many client_telephones" do
    assert ClientTelephoneStatus.reflect_on_association(:client_telephones)
  end

  test "status ids are integers" do
    assert_kind_of Integer, ClientTelephoneStatus::NOTHING
    assert_kind_of Integer, ClientTelephoneStatus::VERIFIED
    assert_kind_of Integer, ClientTelephoneStatus::UNVERIFIED
    assert_kind_of Integer, ClientTelephoneStatus::SUSPENDED
    assert_kind_of Integer, ClientTelephoneStatus::DELETED
  end

  test "ensure_defaults! creates missing default records" do
    ClientTelephoneStatus.where(id: ClientTelephoneStatus::NOTHING).destroy_all

    assert_difference("ClientTelephoneStatus.count") do
      ClientTelephoneStatus.ensure_defaults!
    end
  end

  test "ensure_defaults! skips when all defaults exist" do
    ClientTelephoneStatus.ensure_defaults!

    assert_no_difference("ClientTelephoneStatus.count") do
      ClientTelephoneStatus.ensure_defaults!
    end
  end

  test "restrict_with_error prevents deletion when telephones exist" do
    status = ClientTelephoneStatus.find(ClientTelephoneStatus::VERIFIED)
    user = Client.find_by!(public_id: "one_idxxxxxxxxxxxxxxx")
    ClientTelephone.create!(
      number: "+81901234567",
      user_id: user.id,
      user_telephone_status_id: status.id,
    )

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      status.destroy!
    end
  end
end
