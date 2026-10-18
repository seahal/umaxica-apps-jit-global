# typed: false
# frozen_string_literal: true

require "json"

module Auth
  module App
    module Apple
      class NotificationsController < ActionController::API
        include ActionController::MimeResponds
        include ::RateLimit
        include ::DefaultNoStore

        AUTHENTICATION_MODE = :bare

        prepend_before_action :apply_default_no_store

        MAXIMUM_BODY_BYTES = 32.kilobytes

        rate_limit(
          to: 60,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "auth_app_apple_notification",
          name: "apple_notification_ip",
          store: rate_limit_store,
          only: :create,
          with: -> { head :too_many_requests },
        )

        def create
          return head :unsupported_media_type unless request.media_type == "application/json"
          return head :content_too_large if content_length_exceeds_limit?

          raw_body = request.body.read(MAXIMUM_BODY_BYTES + 1)
          return head :content_too_large if raw_body.bytesize > MAXIMUM_BODY_BYTES

          payload = JSON.parse(raw_body)
          raise JSON::ParserError, "payload object is required" unless payload.is_a?(Hash)

          jws = payload.fetch("payload")
          raise JSON::ParserError, "payload is required" unless jws.is_a?(String) && jws.present?

          ExternalAuthenticationAppleNotificationIngress.call(jws: jws)
          response.set_header("Cache-Control", "no-store")
          head :ok
        rescue JSON::ParserError, ActionDispatch::Http::Parameters::ParseError, KeyError
          head :bad_request
        rescue ExternalAuthentication::AppleNotificationVerifier::VerificationError
          head :unauthorized
        rescue ExternalAuthentication::AppleNotificationVerifier::ConfigurationError,
               ExternalAuthentication::AppleNotificationJwksCache::FetchError
          head :service_unavailable
        end

        private

        def content_length_exceeds_limit?
          request.content_length.present? && request.content_length > MAXIMUM_BODY_BYTES
        end
      end
    end
  end
end
