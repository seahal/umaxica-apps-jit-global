# frozen_string_literal: true

require Rails.root.join("app/subscribers/jwt_anomaly_subscriber").to_s

subscriber = JwtAnomalySubscriber.new
ActiveSupport::Notifications.subscribe("jwt.anomaly.detected") do |event|
  subscriber.emit(event)
end
