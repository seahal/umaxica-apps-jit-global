# typed: false
# frozen_string_literal: true

require "test_helper"

# D-106 (WU-34, AX26): Sign In refuses a principal whose registration never finished. Every Sign In
# issuance and evidence point decides through `sign_in_allowed?`; sign-up keeps `login_allowed?` for
# its own pending principal.
class UnfinishedRegistrationLoginTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an APP Client in an unfinished registration status cannot sign in" do
    client = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, security_mode_id: SecurityModeConfigurable::NORMAL)

    assert_not client.sign_in_allowed?
    assert_predicate client, :login_allowed?
  end

  test "an APP Client whose registration committed can sign in" do
    [ClientStatus::VERIFIED_WITH_SIGN_UP, ClientStatus::ACTIVE].each do |status_id|
      client = Client.create!(status_id: status_id, security_mode_id: SecurityModeConfigurable::NORMAL)

      assert_predicate client, :sign_in_allowed?, status_id.to_s
    end
  end

  test "a COM Visitor in an unfinished registration status cannot sign in" do
    visitor = Visitor.create!(status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP, security_mode_id: SecurityModeConfigurable::NORMAL)

    assert_not visitor.sign_in_allowed?
    assert_predicate visitor, :login_allowed?
  end

  test "a COM Visitor promoted at Finalization can sign in" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, security_mode_id: SecurityModeConfigurable::NORMAL)

    assert_predicate visitor, :sign_in_allowed?
  end
end
