# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/oidc_auth_admission_test_helper"

# `social_ceremony_app_{provider}` must stop the ceremony at its *start*, not
# only at the callback.
#
# The callback gate accepts `:draining` on purpose, so ceremonies issued before
# the switch was flipped can finish. That is only bounded if no new ceremony can
# start: with the start ungated, every new ceremony counts as "issued before the
# disable" and the drain never ends, leaving a switch that looks wired and stops
# nothing.
class SocialCeremonyStartGateTest < ActionDispatch::IntegrationTest
  include OidcAuthAdmissionTestHelper

  PROVIDERS = { "google" => :social_ceremony_app_google, "apple" => :social_ceremony_app_apple }.freeze

  setup do
    bootstrap_auth_sign_in_admission!
  end

  teardown do
    PROVIDERS.each_value { |feature| Flipper.enable(feature) }
  end

  PROVIDERS.each do |provider, feature|
    test "#{provider} sign-in entry hands off while the provider is enabled" do
      post public_send(:"auth_app_social_#{provider}_session_path", ri: "jp")

      assert_response :temporary_redirect
    end

    test "#{provider} sign-in entry is refused while the provider is disabled" do
      Flipper.disable(feature)

      post public_send(:"auth_app_social_#{provider}_session_path", ri: "jp")

      assert_response :see_other
      assert_equal auth_app_sign_in_path, URI.parse(response.location).path
    end

    test "#{provider} sign-up entry issues no sign-up flow while the provider is disabled" do
      Flipper.disable(feature)

      assert_no_difference -> { ClientSignUpFlow.count } do
        post public_send(:"auth_app_social_#{provider}_registration_path", ri: "jp")
      end

      assert_response :see_other
    end

    test "#{provider} entry writes no ceremony state while the provider is disabled" do
      Flipper.disable(feature)

      post public_send(:"auth_app_social_#{provider}_session_path", ri: "jp")

      assert_nil session[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY]
      assert_nil session[SocialAuth::SOCIAL_INTENT_SESSION_KEY]
    end
  end

  test "disabling one provider leaves the other running" do
    Flipper.disable(:social_ceremony_app_google)

    post auth_app_social_apple_session_path(ri: "jp")

    assert_response :temporary_redirect
  end
end
