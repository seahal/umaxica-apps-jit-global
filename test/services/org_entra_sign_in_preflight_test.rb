# typed: false
# frozen_string_literal: true

require "test_helper"

# The preflight is the automatable half of the live smoke test: it reaches
# Microsoft when run for real, so every case here injects the metadata fetcher
# and the suite stays offline.
class OrgEntraSignInPreflightTest < ActiveSupport::TestCase
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  CLIENT_ID = "22222222-3333-4444-5555-666666666666"
  OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  ISSUER = "https://login.microsoftonline.com/#{TENANT_ID}/v2.0"

  setup do
    OperatorEntraIdentityState.ensure_defaults!
  end

  test "passes when configuration, kill switch, tenant and provisioning all agree" do
    provision_active_identity!

    result = run_preflight(metadata: { "issuer" => ISSUER })

    assert_predicate result, :ok?, failed_detail(result)
  end

  # The value must never appear in output that gets pasted into an incident note.
  test "reports the secret by length only, never by value" do
    result = run_preflight(metadata: { "issuer" => ISSUER }, secret: "super-secret-value")
    detail = check(result, "credentials").detail

    assert_includes detail, "18 characters"
    assert_not_includes detail, "super-secret-value"
  end

  test "fails when a credential is missing" do
    result = run_preflight(metadata: { "issuer" => ISSUER }, secret: "")

    assert_not result.ok?
    assert_includes check(result, "credentials").detail, "OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET missing"
  end

  # A wrong tenant id produces a valid-looking configuration whose issuer no
  # verifier will ever accept; catching it here beats catching it in a browser.
  test "fails when the tenant advertises a different issuer" do
    result = run_preflight(metadata: { "issuer" => "https://login.microsoftonline.com/other/v2.0" })

    assert_not result.ok?
    assert_includes check(result, "issuer").detail, "OMNI_AUTH_ENTRA_ORG_TENANT_ID"
  end

  # This output goes into incident and release-gate notes, and every issuer
  # embeds the tenant id.
  test "never echoes an issuer, matching or not" do
    matching = run_preflight(metadata: { "issuer" => ISSUER })
    mismatched = run_preflight(metadata: { "issuer" => "https://login.microsoftonline.com/other/v2.0" })

    [matching, mismatched].each do |result|
      result.checks.each do |candidate|
        assert_not_includes candidate.detail, TENANT_ID
        assert_not_includes candidate.detail, "login.microsoftonline.com"
      end
    end
  end

  # The discovery fetch runs through OutboundHttp::Connection, so an unreachable
  # tenant arrives as a Faraday error rather than the raw SocketError the stdlib
  # transport used to raise. issuer_check names those errors explicitly instead
  # of rescuing StandardError, so a configuration or programming fault inside
  # the check still fails loudly rather than reading as an unreachable tenant.
  test "fails without leaking an exception message when the tenant is unreachable" do
    unreachable = -> { raise Faraday::ConnectionFailed, "getaddrinfo: nodename nor servname provided" }
    result = run_preflight(metadata: unreachable)

    assert_not result.ok?
    detail = check(result, "issuer").detail

    assert_includes detail, "could not reach the tenant"
    assert_not_includes detail, "getaddrinfo"
  end

  test "fails without leaking an exception message when the tenant times out" do
    result = run_preflight(metadata: -> { raise Faraday::TimeoutError, "read timeout" })

    assert_not result.ok?

    assert_includes check(result, "issuer").detail, "could not reach the tenant"
  end

  test "fails when the kill switch is off" do
    result = run_preflight(metadata: { "issuer" => ISSUER }, enabled: false)

    assert_not result.ok?
    assert_includes check(result, "kill_switch").detail, "social_ceremony:enable"
  end

  test "fails when nobody has been provisioned, because nobody could sign in" do
    result = run_preflight(metadata: { "issuer" => ISSUER })

    assert_not result.ok?
    assert_includes check(result, "provisioning").detail, "nobody can sign in yet"
  end

  test "reports the redirect uri literally so it can be compared with the registration" do
    result = run_preflight(metadata: { "issuer" => ISSUER })

    assert_equal ExternalAuthenticationEntraRedirectUri.call, check(result, "redirect_uri").detail
  end

  private

  def provision_active_identity!
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    OperatorEntraIdentity.create!(
      operator_id: operator.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )
  end

  def run_preflight(metadata:, secret: "entra-client-secret", enabled: true)
    fetcher = metadata.respond_to?(:call) ? ->(_tenant) { metadata.call } : ->(_tenant) { metadata }
    feature = ExternalAuthentication::FlipperProviderAvailabilityAdapter::PROVIDER_FEATURE_NAMES.fetch("entra")

    with_credentials(secret) do
      FeatureFlags.stub(:enabled?, ->(name, *) { name == feature && enabled }) do
        OrgEntraSignInPreflight.call(metadata_fetcher: fetcher)
      end
    end
  end

  def with_credentials(secret, &)
    creds = Object.new
    creds.define_singleton_method(:option) do |key, **|
      (key == :OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET) ? secret : nil
    end

    ExternalAuthentication::ProviderRegistry.stub(:tenant_id, ->(_) { TENANT_ID }) do
      ExternalAuthentication::ProviderRegistry.stub(:audience, ->(_) { CLIENT_ID }) do
        ExternalAuthentication::ProviderRegistry.stub(:issuer_for, ->(_) { ISSUER }) do
          Rails.app.stub(:creds, creds, &)
        end
      end
    end
  end

  def check(result, name)
    result.checks.find { |candidate| candidate.name == name } ||

      flunk("no #{name} check in #{result.checks.map(&:name).inspect}")
  end

  def failed_detail(result)
    result.checks.reject(&:ok).map { |c| "#{c.name}: #{c.detail}" }.join("; ")
  end
end
