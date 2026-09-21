# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_token_dbsc_statuses
# Database name: app_ticket
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientTokenDbscStatusTest < ActiveSupport::TestCase
  def setup
    Prosopite.pause do
      ClientTokenDbscStatus::DEFAULTS.each do |id|
        ClientTokenDbscStatus.find_or_create_by!(id: id)
      end
    end
  end

  test "has correct constants" do
    assert_equal 0, ClientTokenDbscStatus::NOTHING
    assert_equal 1, ClientTokenDbscStatus::ACTIVE
    assert_equal 2, ClientTokenDbscStatus::PENDING
    assert_equal 3, ClientTokenDbscStatus::FAILED
    assert_equal 4, ClientTokenDbscStatus::REVOKE
  end

  test "DEFAULTS constant contains all status values" do
    expected = [0, 1, 2, 3, 4]

    assert_equal expected, ClientTokenDbscStatus::DEFAULTS
  end

  test "can load nothing status from db" do
    status = ClientTokenDbscStatus.find(ClientTokenDbscStatus::NOTHING)

    assert_equal 0, status.id
  end

  test "has_many client_tokens association" do
    assert_respond_to ClientTokenDbscStatus.new, :client_tokens
  end

  test "ensure_defaults! creates missing status records" do
    Prosopite.pause do
      ClientTokenDbscStatus.where(id: ClientTokenDbscStatus::REVOKE).destroy_all
    end

    assert_difference("ClientTokenDbscStatus.count", 1) do
      ClientTokenDbscStatus.ensure_defaults!
    end

    assert ClientTokenDbscStatus.exists?(id: ClientTokenDbscStatus::REVOKE)
  end

  test "ensure_defaults! skips existing records" do
    assert_no_difference("ClientTokenDbscStatus.count") do
      ClientTokenDbscStatus.ensure_defaults!
    end
  end

  test "client_tokens association works with dependent restrict" do
    status = ClientTokenDbscStatus.find(ClientTokenDbscStatus::NOTHING)
    user = Client.create!(
      status_id: ClientStatus::NOTHING,
      mfa_level_enabled: false,
    )

    user_token = ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_dbsc_status_id: status.id,
      discard_at: 1.day.from_now,
      purge_eligible_at: 1.day.from_now,
    )

    assert_includes status.client_tokens, user_token

    assert_not status.destroy
    assert_predicate status.errors[:base], :present?
  end
end
