# frozen_string_literal: true

require Rails.root.join("app/subscribers/browser_block_notification_subscriber").to_s

subscriber = BrowserBlockNotificationSubscriber.new
ActiveSupport::Notifications.subscribe("browser_block.action_controller") do |event|
  subscriber.emit(event)
end
