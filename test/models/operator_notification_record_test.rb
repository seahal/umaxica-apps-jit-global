# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_notification_records
# Database name: org_signal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_operator_notification_records_on_public_id  (public_id) UNIQUE
#  index_operator_notification_records_on_staff_id   (staff_id)
#

require "test_helper"

class OperatorNotificationRecordTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "OperatorNotificationRecord", OperatorNotificationRecord.name
  end

  test "belongs to operator through notification_records" do
    operator = Operator.create!
    notification = OperatorNotificationRecord.create!(operator: operator)

    assert_equal operator, notification.operator
    assert_includes operator.notification_records, notification
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorNotificationRecord)
  end
end
