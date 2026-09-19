# typed: false
# frozen_string_literal: true

require "test_helper"

# The provider callbacks are GET routes today, so Rails treats them as verified and this
# rejection path is latent. It becomes live as soon as a callback accepts a non-GET request
# (for example an Apple `form_post` response). The harness below drives the real Rails
# forgery-protection pipeline with a POST to the callback action, and covers both the normal
# case (the guard recorded a rejection reason) and the abnormal one (it did not).
class SocialOmniauthCallbackFlowUnverifiedRequestTest < ActionDispatch::IntegrationTest
  # A bare controller on purpose: ApplicationController adds the host/FQDN gates, which would
  # answer before forgery protection runs, and this test is about forgery protection only.
  class HarnessController < ActionController::Base # rubocop:disable Rails/ApplicationController
    include SocialCallbackGuard
    include SocialOmniauthCallbackFlow

    protect_from_forgery with: :exception

    def omniauth
      head :ok
    end

    def other
      head :ok
    end

    private

    def social_auth_failure_redirect_path
      "/social/failure"
    end
  end

  CROSS_SITE = { "Sec-Fetch-Site" => "cross-site", "Origin" => "https://attacker.example" }.freeze

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @log = StringIO.new
    @previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(@log)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    Rails.logger = @previous_logger
  end

  test "an unverified callback without a recorded guard rejection is rejected, not raised" do
    with_harness_route do
      post "/harness/social/callback", params: { provider: "google" }, headers: CROSS_SITE,
                                       env: { "social_callback_guard.verified" => false }

      assert_response :forbidden
      assert_equal "/social/failure", URI.parse(response.location).path
      assert_includes @log.string, 'provider="google"'
      assert_includes @log.string, "reason=csrf_unverified"
    end
  end

  test "an unverified callback uses the rejection the guard recorded" do
    with_harness_route do
      post "/harness/social/callback",
           params: { provider: "google" }, headers: CROSS_SITE,
           env: {
             "social_callback_guard.verified" => false,
             "social_callback_guard.rejection" => {
               reason: "host_mismatch", provider: "google", details: { host: "evil.example" },
             },
           }

      assert_response :forbidden
      assert_equal "/social/failure", URI.parse(response.location).path
      assert_includes @log.string, "reason=host_mismatch"
    end
  end

  test "a verified guard verdict does not bypass the rejection for another action" do
    with_harness_route do
      post "/harness/social/other", params: { provider: "google" }, headers: CROSS_SITE,
                                    env: { "social_callback_guard.verified" => true }

      assert_response :unprocessable_content
    end
  end

  private

  def with_harness_route
    with_routing do |set|
      set.draw do
        post("/harness/social/callback", to: "social_omniauth_callback_flow_unverified_request_test/harness#omniauth")
        post("/harness/social/other", to: "social_omniauth_callback_flow_unverified_request_test/harness#other")
      end
      yield
    end
  end
end
