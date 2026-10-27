# frozen_string_literal: true

require "test_helper"

class SocialCallbackRefusalMatrixTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  # The database FK prevents orphan rows. Only that impossible storage boundary is replaced;
  # admission, provider state, resolution, HTTP handling and allocation checks remain real.
  OrphanIdentity =
    Struct.new(:state) do
      def association(_name)
        Struct.new(:scope).new(Struct.new(:take).new(nil))
      end
    end

  setup do
    [
      ClientStatus, ClientVisibility, ClientMfaStatus,
      OperatorStatus, OperatorVisibility, OperatorMfaStatus,
    ].each(&:ensure_defaults!)
    ClientSecurityMode.insert_missing_fixed_ids!(ClientSecurityMode::DEFAULTS)
    OperatorSecurityMode.insert_missing_fixed_ids!(OperatorSecurityMode::DEFAULTS)
    @previous_protection = ActionController::Base.allow_forgery_protection
    @previous_omniauth_mode = OmniAuth.config.test_mode
    ActionController::Base.allow_forgery_protection = true
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_protection
    OmniAuth.config.test_mode = @previous_omniauth_mode
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "A07-1e/A08/A34-2: inconsistent and unfinished callbacks refuse with no authority" do
    %w(google apple).product(
      %w(sign_in sign_up),
      %w(unknown registered unusable orphan released unfinished revoked deleted
         banned), %w(html json),
    ).each_with_index do |(provider, intent, state, format), browser_index|
      next if format == "json" && state != "orphan"

      browser = open_session
      # Each partition is an independent browser; retain real rate limiting within its journey.
      browser.remote_addr = "198.51.100.#{browser_index + 1}"
      visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
      auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      browser.host!(visa_host)
      browser.https!
      navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
      client = OidcClientRegistry.find!("core-app-jp")
      authorization = {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        scope: "openid profile",
      }
      authorization[:prompt] = "create" if intent == "sign_up"
      browser.get("/oauth/authorize", params: authorization, headers: navigation)

      assert_equal 303, browser.response.status
      12.times do
        break unless browser.response.redirect?

        target = URI.parse(browser.response.location)
        if target.host == "jump.umaxica.net"
          rt = Rack::Utils.parse_nested_query(target.query).fetch("rt")
          # Follow the Rails-issued target only; external Jump deployment is outside this test.
          target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
        end

        assert_includes [visa_host, auth_host], target.host
        browser.host!(target.host)
        browser.get(target.request_uri, headers: navigation)
      end

      assert_equal 200, browser.response.status
      assert_equal auth_host, browser.host
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
      subject = "http-matrix-#{SecureRandom.hex(12)}"
      issuer = (provider == "google") ? "https://accounts.google.com" : "https://appleid.apple.com"
      OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
        provider:, uid: subject, info: { name: "Provider fixture" },
        credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
      )
      entry_path =
        case [provider, intent]
        when ["google", "sign_in"] then auth_app_social_google_session_path
        when ["google", "sign_up"] then auth_app_social_google_registration_path
        when ["apple", "sign_in"] then auth_app_social_apple_session_path
        when ["apple", "sign_up"] then auth_app_social_apple_registration_path
        end
      browser.post(entry_path, params: { ri: "jp" }, headers:)

      assert_equal 307, browser.response.status, "#{provider}/#{intent}/#{state} start"
      callback_state = browser.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
      sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      continuity = browser.cookies[sid_cookie]
      binding = ClientAuthAdmissionBinding.order(:id).last
      ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
      headers["Accept"] = "application/json" if format == "json"
      unless %w(unknown orphan banned).include?(state)
        status_id =
          case state
          when "unusable" then ClientStatus::RESERVED
          when "unfinished" then ClientStatus::UNVERIFIED_WITH_SIGN_UP
          else ClientStatus::ACTIVE
          end
        actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id:, birthdate: "2000-01-01")
        identity_state =
          case state
          when "revoked" then "consent_revoked"
          when "deleted" then "account_deleted"
          else "active"
          end
        identity = ClientExternalIdentity.create!(
          client: actor, provider:, issuer:, subject:, audience: "#{provider}-test-client-id",
          verification_authority: "provider-fixture", verified_at: Time.current, state: identity_state,
        )
        identity.release! if state == "released"
      end
      if state == "banned"
        actor = Client.create!(security_mode_id: ClientSecurityMode::NORMAL, status_id: ClientStatus::ACTIVE)
        operator = Operator.create!(
          security_mode_id: OperatorSecurityMode::ADVANCED, status_id: OperatorStatus::ACTIVE,
          visibility_id: OperatorVisibility::STAFF,
        )
        enforcement_case = AppEnforcementCase.create!(
          kind: "permanent_ban", duration_mode: "permanent", visibility: "visible", release_mode: "break_glass_only",
          effective_at: 1.minute.ago, reason_code: "abuse", principal_public_id: actor.public_id,
          applied_by_operator_public_id: operator.public_id,
        )
        digest = EnforcementIdentifierDigest.for_social_subject(
          realm: "app", identifier_kind: "#{provider}_subject",
          issuer:, subject:,
        )
        AppEnforcementIdentifierEffect.create!(**digest, enforcement_case:, effective_at: 1.minute.ago)
      end
      callback_path =
        (provider == "google") ? auth_app_social_google_callback_path : auth_app_social_apple_callback_path
      fatal_events = []
      assert_no_difference(
        ["Client.count", "ClientSignUpFlow.count", "ClientToken.count",
         "ClientExternalIdentity.count",],
      ) do
        if state == "orphan"
          repository = ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider:)
          repository.stub(:find_by_subject_for_link, OrphanIdentity.new("active")) do
            ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.stub(:new, repository) do
              Rails.logger.stub(:fatal, ->(message) { fatal_events << message.to_s }) do
                browser.get(callback_path, params: { state: callback_state, ri: "jp" }, headers:)
              end
            end
          end
        else
          browser.get(callback_path, params: { state: callback_state, ri: "jp" }, headers:)
        end
      end
      expected_status =
        if state == "orphan"
          500
        elsif state == "registered" && intent == "sign_in"
          303
        elsif state == "unusable" && intent == "sign_in"
          403
        elsif state == "unknown" && intent == "sign_up"
          302
        else
          # D-47 / D-198: a refused sign-path callback ends in place with the uniform 400.
          400
        end

      assert_equal expected_status, browser.response.status, "#{provider}/#{intent}/#{state} callback"
      if state == "orphan"
        assert_equal 1, fatal_events.count { |event| event.include?("social_auth.identity_without_client") }
        assert_not_includes fatal_events.join, subject
        assert_not_includes fatal_events.join, "provider-fixture"
        assert_not_includes fatal_events.join, "@example.test"
        assert_predicate continuity, :present?
        assert_equal continuity, browser.cookies[sid_cookie]
      end

      successful = (state == "registered" && intent == "sign_in") || (state == "unknown" && intent == "sign_up")

      assert_equal successful, ceremony.reload.authentication_evidence_recorded?,
                   "#{provider}/#{intent}/#{state} evidence"
      assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    end
  end
end
