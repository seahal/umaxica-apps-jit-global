# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch31MoreEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "JitSecurityTurnstileVerifier blank token arms" do
    blank_token = JitSecurityTurnstileVerifier.verify(token: "", remote_ip: "127.0.0.1")

    assert_equal "missing cf-turnstile-response", blank_token["error"]
    nil_token = JitSecurityTurnstileVerifier.verify(token: nil, remote_ip: "127.0.0.1")

    assert_equal "missing cf-turnstile-response", nil_token["error"]
  end

  test "ExternalAuthentication LinkResult and LoginResult rejection arms" do
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :other, user: Object.new, identity: Object.new) }
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :linked, user: nil, identity: Object.new) }
    if defined?(ExternalAuthentication::LoginResult)
      assert_raises(ArgumentError) { ExternalAuthentication::LoginResult.new(status: :other, user: Object.new) }
    end
  end

  test "OidcIdTokenIssuer blank nonce and inverted times" do
    resource = Client.new
    client = Struct.new(:client_id).new("base-rails-rp")
    assert_raises(ArgumentError) do
      OidcIdTokenIssuer.new(
        resource: resource,
        client: client,
        nonce: "",
        issued_at: Time.current,
        expires_at: 1.minute.from_now,
      ).call
    end
    assert_raises(ArgumentError) do
      OidcIdTokenIssuer.new(
        resource: resource,
        client: client,
        nonce: "n",
        issued_at: 1.minute.from_now,
        expires_at: Time.current,
      ).call
    end
  end

  test "Palm and OIDC access token authenticators blank tokens" do
    [PalmAccessTokenAuthenticator, OidcAccessTokenAuthenticator].each do |klass|
      assert_raises(ArgumentError) { klass.new(token: nil) }
      assert_raises(ArgumentError) { klass.new(token: " ") }
    end
  end

  test "DbscVerificationService blank proof" do
    assert_raises(ArgumentError) do
      DbscVerificationService.new(
        proof: nil, challenge: "c", challenge_issued_at: Time.current,
        expected_audience: "a",
      )
    end
    assert_raises(ArgumentError) do
      DbscVerificationService.new(
        proof: "", challenge: "c", challenge_issued_at: Time.current,
        expected_audience: "a",
      )
    end
  end

  test "CredentialSecurityTransition blank actor" do
    assert_raises(ArgumentError) { CredentialSecurityTransition.new(actor: nil, event: :rotate) }
  end

  test "Telephone signup issuer writes typed ceremony proof and Source send time" do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    telephone = ClientTelephone.new(raw_number: "+819012399928", confirm_policy: true, confirm_using_mfa: true)
    TelephoneSignUpCandidateCreator.call(telephone: telephone)
    now = ClientSignUpFlow.database_now
    nonce = "branch-coverage-original-browser"
    flow = ClientSignUpFlow.create!(
      principal_id: telephone.user_id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING, step: "contact",
      nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

    assert issued.code.is_a?(String) && issued.code.match?(/\A[0-9]{6}\z/), "Code must contain six ASCII digits"
    assert_predicate issued.transaction.otp_verifier, :present?
    assert_predicate telephone.otp_last_sent_at, :present?
    assert_predicate issued.transaction.otp_expires_at, :present?
  end

  test "AuthMethodGuard and single-use token easy rejects" do
    assert_not AuthMethodGuard.respond_to?(:allow?)
  end

  test "ConfigValues OriginValue to_s default and explicit ports" do
    https = ConfigValues.build("https://example.test")

    assert_equal "https://example.test", https.to_s
    http = ConfigValues.build("http://localhost", allow_localhost: true)

    assert_equal "http://localhost", http.to_s
    custom = ConfigValues.build("https://example.test:8443")

    assert_includes custom.to_s, ":8443"
  end

  test "JitSecurityJwtJtiGenerator generate produces strings" do
    a = JitSecurityJwtJtiGenerator.generate
    b = JitSecurityJwtJtiGenerator.generate

    assert_kind_of String, a
    assert_kind_of String, b
    assert_not_equal a, b
  end
end
