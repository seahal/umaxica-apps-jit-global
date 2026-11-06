# typed: false
# frozen_string_literal: true

require "aws-sdk-sns"

class OutboundSmsProvidersAwsSns
  HTTP_OPEN_TIMEOUT = 5
  HTTP_READ_TIMEOUT = 10

  def initialize
    @client = Aws::SNS::Client.new(client_options)
  end

  def send_message(to:, title:, body:)
    validate_params(to: to, body: body)

    response = @client.publish(
      phone_number: to,
      message: body,
      subject: title.presence || "SMS",
    )

    OutboundProviderResponse.accepted(
      provider: :aws_sns,
      provider_reference: response.message_id,
    )
  end

  private

  def client_options
    options = {
      access_key_id: Rails.app.creds.require(:AWS_ACCESS_KEY_ID),
      secret_access_key: Rails.app.creds.require(:AWS_SECRET_ACCESS_KEY),
      region: Rails.application.config.aws_region || "ap-northeast-1",
      http_open_timeout: HTTP_OPEN_TIMEOUT,
      http_read_timeout: HTTP_READ_TIMEOUT,
    }
    session_token = Rails.app.creds.option(:AWS_SESSION_TOKEN)
    options[:session_token] = session_token if session_token.present?
    options
  end

  def validate_params(to:, body:)
    raise ArgumentError, "Phone number is required" if to.blank?
    raise ArgumentError, "Message is required" if body.blank?
  end
end
