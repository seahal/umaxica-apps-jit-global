# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcConnectionRecorderTest < ActiveSupport::TestCase
  setup do
    ClientStatus.ensure_defaults!
    @user = Client.create!(public_id: "recorder_#{SecureRandom.hex(5)}", status_id: ClientStatus::ACTIVE)
    @client = Data.define(:client_id).new("core-next-rp")
  end

  test "records first use at the surface writer database time by default" do
    database_now = Time.utc(2026, 9, 21, 13, 14, 15)

    ClientOidcConnection.stub(:database_now, database_now) do
      OidcConnectionRecorder.call(
        resource: @user,
        client: @client,
        scope: "openid profile",
        authorization_issued_at: database_now - 1.minute,
      )
    end

    connection = ClientOidcConnection.find_by!(user: @user, client_id: @client.client_id)

    assert_equal database_now, connection.last_used_at
  end
end
