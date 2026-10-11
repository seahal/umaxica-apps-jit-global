# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationPushNotificationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  self.fixture_table_names = []

  test "ApplicationPushNotification inherits from ActionPushNative::Notification" do
    assert_equal "ActionPushNative::Notification", ApplicationPushNotification.superclass.name
  end

  test "can be instantiated with title and body" do
    notification = ApplicationPushNotification.new(
      title: "Test Title",
      body: "Test Body",
    )

    assert_instance_of ApplicationPushNotification, notification
    assert_equal "Test Title", notification.title
    assert_equal "Test Body", notification.body
  end

  test "can be instantiated with all attributes" do
    notification = ApplicationPushNotification.new(
      title: "Title",
      body: "Body",
      badge: 1,
      thread_id: "thread-1",
      sound: "default",
      high_priority: false,
      apple_data: { aps: { alert: "test" } },
      google_data: { notification: { title: "test" } },
      data: { custom_key: "custom_value" },
      custom_context: "context_value",
    )

    assert_equal "Title", notification.title
    assert_equal "Body", notification.body
    assert_equal 1, notification.badge
    assert_equal "thread-1", notification.thread_id
    assert_equal "default", notification.sound
    assert_not notification.high_priority
    assert_equal({ aps: { alert: "test" } }, notification.apple_data)
    assert_equal({ notification: { title: "test" } }, notification.google_data)
    assert_equal({ custom_key: "custom_value" }, notification.data)
    assert_equal "context_value", notification.context[:custom_context]
  end

  test "defaults high_priority to true" do
    notification = ApplicationPushNotification.new

    assert notification.high_priority
  end

  test "defaults apple_data and google_data to empty hash" do
    notification = ApplicationPushNotification.new

    assert_equal({}, notification.apple_data)
    assert_equal({}, notification.google_data)
  end

  test "deliver_to does nothing when disabled" do
    notification = ApplicationPushNotification.new(title: "Test", body: "Test")
    mock_device = Minitest::Mock.new

    result = notification.deliver_to(mock_device)

    assert_nil result
  end

  test "as_json returns correct hash" do
    notification = ApplicationPushNotification.new(
      title: "Title",
      body: "Body",
      data: { key: "value" },
    )

    json = notification.as_json

    assert_equal "Title", json[:title]
    assert_equal "Body", json[:body]
    assert_equal({ key: "value" }, json[:data])
    assert_not_includes json, :custom_context
  end

  test "enabled is false in test environment" do
    assert_not ApplicationPushNotification.enabled
  end

  test "delivery queue is explicitly the default worker queue" do
    assert_equal "default", ApplicationPushNotification.queue_name.to_s
  end

  test "delivery is enqueued on the explicit default queue" do
    notification = ApplicationPushNotification.new(title: "Title", body: "Body")

    assert_enqueued_with(job: ApplicationPushNotificationJob, queue: "default") do
      notification.deliver_later_to("device-1")
    end
  end
end
