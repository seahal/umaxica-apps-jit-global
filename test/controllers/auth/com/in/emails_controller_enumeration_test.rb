# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth
  module Com
    module In
      class EmailsControllerEnumerationTest < ActionDispatch::IntegrationTest
        REGISTERED_ADDRESS = "com_enumeration_registered@example.com"
        UNREGISTERED_ADDRESS = "com_enumeration_unregistered@example.com"

        setup do
          host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
          TurnstileVerifierStub.challenge_enabled = true
          TurnstileVerifierStub.challenge_response = { "success" => true }

          visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
          VisitorEmail.create!(visitor: visitor, address: REGISTERED_ADDRESS, confirm_policy: true)
        end

        teardown do
          TurnstileVerifierStub.challenge_enabled = false
          TurnstileVerifierStub.challenge_response = nil
        end

        test "fresh sessions receive the same cooldown response for registered and unregistered addresses" do
          registered = cooldown_response_for(REGISTERED_ADDRESS)
          unregistered = cooldown_response_for(UNREGISTERED_ADDRESS)

          assert_equal 429, registered[:status]
          assert_equal registered[:status], unregistered[:status]
          assert_equal registered[:body], unregistered[:body]
        end

        private

        def cooldown_response_for(address)
          responses =
            2.times.map do
              response = nil
              open_session do |session|
                session.host!(ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost"))
                session.post(
                  auth_com_sign_in_email_url(ri: "jp"), params: {
                    :user_email => { address: address },
                    "cf-turnstile-response" => "test_token",
                  },
                )
                response = { status: session.response.status, body: session.response.body }
              end
              response
            end

          responses.last
        end
      end
    end
  end
end
