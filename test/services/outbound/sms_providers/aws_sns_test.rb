# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "aws-sdk-sns"

module Outbound
  module SmsProviders
    class AwsSnsTest < ActiveSupport::TestCase
      test "raises ArgumentError when phone number is blank" do
        provider = build_provider

        assert_raises(ArgumentError) do
          provider.send_message(to: "", title: "Title", body: "Hello")
        end

        assert_raises(ArgumentError) do
          provider.send_message(to: nil, title: "Title", body: "Hello")
        end
      end

      test "raises ArgumentError when body is blank" do
        provider = build_provider

        assert_raises(ArgumentError) do
          provider.send_message(to: "+1234567890", title: "Title", body: "")
        end

        assert_raises(ArgumentError) do
          provider.send_message(to: "+1234567890", title: "Title", body: nil)
        end
      end

      test "sends message with default subject" do
        fake_client = FakeSnsClient.new
        provider = build_provider(fake_client)
        result = provider.send_message(to: "+1234567890", title: nil, body: "Hello World")

        assert_equal "aws_sns", result.provider
        assert_equal "test-id", result.provider_reference
        assert_kind_of ActiveSupport::TimeWithZone, result.accepted_at
        assert_equal(
          [{ phone_number: "+1234567890", message: "Hello World", subject: "SMS" }],
          fake_client.calls,
        )
      end

      test "sends message with custom subject" do
        fake_client = FakeSnsClient.new
        provider = build_provider(fake_client)
        result = provider.send_message(to: "+1234567890", title: "Custom Subject", body: "Hello World")

        assert_equal "aws_sns", result.provider
        assert_equal "test-id", result.provider_reference
        assert_equal(
          [{ phone_number: "+1234567890", message: "Hello World", subject: "Custom Subject" }],
          fake_client.calls,
        )
      end

      test "passes session token when configured" do
        captured_options = nil
        fake_creds = FakeCreds.new(session_token: "session-token")

        Rails.app.stub(:creds, fake_creds) do
          ::Aws::SNS::Client.stub(
            :new, ->(options) {
                    captured_options = options
                    OpenStruct.new
                  },
          ) do
            OutboundSmsProvidersAwsSns.new
          end
        end

        assert_equal "session-token", captured_options[:session_token]
      end

      private

      class FakeCreds
        def initialize(session_token: nil)
          @session_token = session_token
        end

        def require(key)
          {
            AWS_ACCESS_KEY_ID: "key",
            AWS_SECRET_ACCESS_KEY: "secret_credential",
          }.fetch(key)
        end

        def option(key)
          return @session_token if key == :AWS_SESSION_TOKEN

          nil
        end
      end

      class FakeSnsClient
        attr_reader :calls

        def initialize
          @calls = []
        end

        def publish(phone_number:, message:, subject:)
          @calls << { phone_number: phone_number, message: message, subject: subject }
          OpenStruct.new(message_id: "test-id")
        end
      end

      def build_provider(client = OpenStruct.new)
        ::Aws::SNS::Client.stub(:new, client) do
          OutboundSmsProvidersAwsSns.new
        end
      end
    end
  end
end
