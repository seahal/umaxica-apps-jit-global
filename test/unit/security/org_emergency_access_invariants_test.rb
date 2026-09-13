# typed: false
# frozen_string_literal: true

require "test_helper"

# Structural guards for Emergency Access.
#
# Each rule here is a boundary that a plausible future change could erase
# quietly: adding the ceremony to another surface, reshaping the routes into
# business verbs, or -- the one that matters most -- growing a second copy of
# the WebAuthn verification code so a fix could land in one path and not the
# other.
class OrgEmergencyAccessInvariantsTest < ActiveSupport::TestCase
  EMERGENCY_ROUTES = {
    "GET" => "/sign/in/emergency/passkey/new",
    "POST" => %w(/sign/in/emergency/passkey/options /sign/in/emergency/passkey/verification),
  }.freeze

  def org_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")

  def app_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")

  def com_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")

  def recognizes?(host, method, path)
    Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)
    true
  rescue ActionController::RoutingError
    false
  end

  test "org publishes the emergency sign-in ceremony" do
    assert recognizes?(org_host, "GET", "/sign/in/emergency/passkey/new")
    assert recognizes?(org_host, "POST", "/sign/in/emergency/passkey/options")
    assert recognizes?(org_host, "POST", "/sign/in/emergency/passkey/verification")
  end

  test "app and com publish no emergency sign-in ceremony" do
    [app_host, com_host].each do |host|
      # Guard against a host name that resolves to nothing, which would make
      # every assertion below pass for the wrong reason.
      assert recognizes?(host, "GET", "/sign/in/passkey/new"),
             "#{host} does not look like a live auth surface; the negative assertions would be vacuous"

      EMERGENCY_ROUTES.each do |method, paths|
        Array(paths).each do |path|
          assert_not recognizes?(host, method, path),
                     "#{host} must not publish #{method} #{path}; Emergency Access is org only"
        end
      end
    end
  end

  test "the emergency ceremony recognizes only its intended verbs" do
    assert_not recognizes?(org_host, "POST", "/sign/in/emergency/passkey/new")
    assert_not recognizes?(org_host, "GET", "/sign/in/emergency/passkey/options")
    assert_not recognizes?(org_host, "GET", "/sign/in/emergency/passkey/verification")
    assert_not recognizes?(org_host, "DELETE", "/sign/in/emergency/passkey/verification")
  end

  test "the existing normal org sign-in URLs are unchanged" do
    assert recognizes?(org_host, "GET", "/sign/in")
    assert recognizes?(org_host, "GET", "/sign/in/passkey/new")
    assert recognizes?(org_host, "POST", "/sign/in/passkey/options")
    assert recognizes?(org_host, "POST", "/sign/in/passkey/verification")
    assert recognizes?(org_host, "GET", "/sign/in/secret/new")
    assert recognizes?(org_host, "POST", "/sign/in/secret")
  end

  # Emergency Access is a policy, not a protocol: it must not acquire its own
  # sign-up, its own sign-out, or a business-verb endpoint that would let it
  # drift away from the shared ceremony shape.
  test "no emergency sign-up, sign-out, or business-verb route exists" do
    forbidden = %w(
      /sign/up/emergency
      /sign/in/emergency/passkey/login
      /sign/in/emergency/passkey/authenticate
      /sign/in/emergency/passkey/verify
      /sign/out/emergency
      /sign/in/emergency/session
    )

    forbidden.each do |path|
      %w(GET POST DELETE).each do |method|
        assert_not recognizes?(org_host, method, path), "#{method} #{path} must not exist"
      end
    end
  end

  test "emergency routes are named after the same resources as the normal ceremony" do
    assert_equal(
      "/sign/in/emergency/passkey/new",
      Rails.application.routes.url_helpers.new_auth_org_sign_in_emergency_passkey_path,
    )
    assert_equal(
      "/sign/in/emergency/passkey/options",
      Rails.application.routes.url_helpers.auth_org_sign_in_emergency_passkey_options_path,
    )
    assert_equal(
      "/sign/in/emergency/passkey/verification",
      Rails.application.routes.url_helpers.auth_org_sign_in_emergency_passkey_verification_path,
    )
  end

  # The seam, stated as a structural fact rather than as a comment: both org
  # ceremonies reach WebAuthn through the same concern, so neither controller
  # can carry verification code of its own.
  test "the normal and emergency org ceremonies share one passkey sign-in implementation" do
    [
      Auth::Org::Sign::In::Passkey::OptionsController,
      Auth::Org::Sign::In::Passkey::VerificationsController,
      Auth::Org::Sign::In::Emergency::Passkey::OptionsController,
      Auth::Org::Sign::In::Emergency::Passkey::VerificationsController,
    ].each do |controller|
      assert_includes controller.ancestors, PasskeySignInFlow,
                      "#{controller} must run the shared passkey sign-in flow"
      assert_includes controller.ancestors, PasskeyCeremonyContext,
                      "#{controller} must use the shared challenge/ceremony context"
    end
  end

  test "no emergency-specific verifier or challenge store exists" do
    forbidden = %w(
      EmergencyPasskeyVerifier
      EmergencyWebauthnVerifier
      EmergencyChallengeStore
    )

    offenders = forbidden.select { |name| Object.const_defined?(name) }

    assert_empty offenders,
                 "Emergency Access is a different authentication policy, not a different " \
                 "cryptographic implementation: #{offenders.join(", ")}"
  end

  test "no source file defines a parallel emergency webauthn implementation" do
    offenders =
      Rails.root.glob("app/**/*.rb").select do |path|
        source = path.read
        source.match?(/Emergency/i) && source.match?(/WebAuthn::Credential\.from_(get|create)/)
      end

    assert_empty offenders.map { |path| path.relative_path_from(Rails.root).to_s },
                 "assertion verification must stay in Webauthn::AssertionVerifier for both ceremonies"
  end

  test "the emergency ceremony purpose is registered in both closed registries" do
    assert_includes Webauthn::ChallengeStore::PURPOSES, "emergency_sign_in"
    assert_equal(
      Webauthn::UvPolicy::REQUIRED,
      Webauthn::UvPolicy.for(:emergency_sign_in).client_value,
      "Emergency Access must not be the ceremony where UV is relaxed",
    )
  end
end
