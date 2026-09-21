# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Auth
  module App
    module In
      # The email sign-in flow is deliberately built for non-disclosure: it performs
      # dummy OTP work, stores dummy state, and normalizes elapsed time so that an
      # unregistered address is indistinguishable from a registered one.
      #
      # The cooldown response used to break that by returning a different message
      # when the address belonged to a login-eligible account, which made resubmitting
      # the same address twice an account-existence oracle.
      class EmailsControllerEnumerationTest < ActionDispatch::IntegrationTest
        fixtures :clients, :client_statuses, :client_email_statuses

        REGISTERED_ADDRESS = "enumeration_registered@example.com"
        UNREGISTERED_ADDRESS = "enumeration_unregistered@example.com"

        setup do
          host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
          TurnstileVerifierStub.challenge_enabled = true
          TurnstileVerifierStub.challenge_response = { "success" => true }

          clients(:one).update!(status_id: ClientStatus::ACTIVE)
          ClientEmail.create!(user: clients(:one), address: REGISTERED_ADDRESS, confirm_policy: true)
        end

        teardown do
          TurnstileVerifierStub.challenge_enabled = false
          TurnstileVerifierStub.challenge_response = nil
        end

        test "the cooldown response is identical for registered and unregistered addresses" do
          registered = cooldown_response_for(REGISTERED_ADDRESS)
          unregistered = cooldown_response_for(UNREGISTERED_ADDRESS)

          assert_equal 429, registered[:status],
                       "Resubmitting the same address inside the send cooldown must be rate limited."
          assert_equal registered[:status], unregistered[:status],
                       "A different status code for a registered address leaks account existence."
          assert_equal registered[:body], unregistered[:body],
                       "A different cooldown message for a registered address leaks account existence. " \
                       "Registered: #{registered[:body].inspect}, unregistered: #{unregistered[:body].inspect}"
        end

        test "a failed Turnstile request does not reserve the address-wide bucket" do
          TurnstileVerifierStub.challenge_response = { "success" => false }
          open_session do |session|
            session.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"))
            session.post(
              auth_app_sign_in_email_url(ri: "jp"), params: {
                :user_email => { address: REGISTERED_ADDRESS },
                "cf-turnstile-response" => "invalid_token",
              },
            )

            assert_equal 422, session.response.status
          end

          TurnstileVerifierStub.challenge_response = { "success" => true }
          open_session do |session|
            session.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"))
            session.post(
              auth_app_sign_in_email_url(ri: "jp"), params: {
                :user_email => { address: REGISTERED_ADDRESS },
                "cf-turnstile-response" => "valid_token",
              },
            )

            assert_equal 302, session.response.status
          end
        end

        private

        # Submits each request in a fresh session so a browser cookie cannot hide
        # a server-side registered/unregistered difference.
        def cooldown_response_for(address)
          responses =
            2.times.map do
              response = nil
              open_session do |session|
                session.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"))
                session.post(
                  auth_app_sign_in_email_url(ri: "jp"), params: {
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

# rubocop:enable I18n/RailsI18n/DecorateString
