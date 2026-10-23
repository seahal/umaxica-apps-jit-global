# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_notification_records
# Database name: app_signal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_notification_records_on_public_id  (public_id) UNIQUE
#  index_client_notification_records_on_user_id    (user_id)
#

require "test_helper"

class ClientNotificationRecordTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "ClientNotificationRecord", ClientNotificationRecord.name
  end

  test "belongs to client through notification_records" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    notification = ClientNotificationRecord.create!(client: client)

    assert_equal client, notification.client
    assert_includes client.notification_records, notification
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ClientNotificationRecord)
  end
end
