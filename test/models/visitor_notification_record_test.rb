# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_notification_records
# Database name: com_signal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  visitor_id :bigint           not null
#
# Indexes
#
#  index_visitor_notification_records_on_public_id   (public_id) UNIQUE
#  index_visitor_notification_records_on_visitor_id  (visitor_id)
#
require "test_helper"

class VisitorNotificationRecordTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "VisitorNotificationRecord", VisitorNotificationRecord.name
  end

  test "belongs to visitor" do
    visitor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    notification = VisitorNotificationRecord.create!(visitor: visitor)

    assert_equal visitor, notification.visitor
    assert_includes visitor.notification_records, notification
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::VisitorNotificationRecord)
  end
end
