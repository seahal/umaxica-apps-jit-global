# frozen_string_literal: true

require Rails.root.join("app/subscribers/deprecation_notification_subscriber").to_s

# Initializers do not run during application-code reloads, so this stays a single process-level
# subscription.
ActiveSupport::Notifications.subscribe(DeprecationNotificationSubscriber::NOTIFICATION_PATTERN) do |event|
  DeprecationNotificationSubscriber.new.emit(event)
end
