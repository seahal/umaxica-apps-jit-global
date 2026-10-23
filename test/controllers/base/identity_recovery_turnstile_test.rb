# typed: false
# frozen_string_literal: true

require "test_helper"

# D-141 / D-156: the APP and COM recovery send branch verifies visible Turnstile before the
# address is resolved; the verify branch (`pass_code`) does not require it.
class BaseIdentityRecoveryTurnstileTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  self.fixture_table_names = []

  SURFACES = {
    app: ["PUBLIC_BASE_SERVICE_URL", :base_app_identity_recovery_session_url],
    com: ["PUBLIC_BASE_CORPORATE_URL", :base_com_identity_recovery_session_url],
  }.freeze

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  SURFACES.each do |surface, (host_env, url_helper)|
    test "#{surface} recovery send without a valid Turnstile issues nothing and re-renders a challenge" do
      host = ENV.fetch(host_env)
      host! host
      TurnstileVerifierStub.challenge_enabled = true

      [
        [nil, { "success" => false }],
        ["invalid-turnstile-token", { "success" => false }],
        ["provider-outage-token", { "success" => false, "unavailable" => true }],
      ].each do |token, verification|
        TurnstileVerifierStub.challenge_response = verification
        params = { recovery_reentry: { address: "recovery-turnstile-#{surface}@example.test" } }
        params["cf-turnstile-response"] = token if token

        assert_no_enqueued_jobs do
          post public_send(url_helper, ri: "jp", host: host), params: params
        end

        assert_response :unprocessable_content
        props = inertia_props

        assert_equal "render", props.fetch("address_form").fetch("turnstile").fetch("mode")
        assert_predicate props.fetch("address_form").fetch("turnstile").fetch("challenge_id"), :present?
        assert_equal [I18n.t("turnstile_error")], props.fetch("errors")
        assert_nil session[EnforcementRecoveryCeremonyFlow::REENTRY_SESSION_KEY]
      end
    end

    test "#{surface} recovery page renders the visible Turnstile on the address form only" do
      host = ENV.fetch(host_env)
      host! host

      get public_send(:"new_#{url_helper}", ri: "jp", host: host)

      assert_response :success
      props = inertia_props

      assert_equal "render", props.fetch("address_form").fetch("turnstile").fetch("mode")
      assert_nil props.fetch("pass_code_form")
    end

    test "#{surface} recovery verify branch does not require Turnstile" do
      host = ENV.fetch(host_env)
      host! host
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => false }

      post public_send(url_helper, ri: "jp", host: host), params: { pass_code: "123456" }

      # Without a live re-entry state the code is refused by the OTP branch, never by Turnstile.
      assert_not_includes response.body, I18n.t("turnstile_error")
    end
  end
end
