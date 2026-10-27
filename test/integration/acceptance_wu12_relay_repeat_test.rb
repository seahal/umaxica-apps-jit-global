# frozen_string_literal: true

require "test_helper"

class AcceptanceWu12RelayRepeatTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "A12-3: attach repeats use the original 9/10/11 second issuance window" do
    statuses = []
    repeated_locations = []
    expected_locations = []
    offsets = [9.seconds, 10.seconds, 11.seconds]
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }

    offsets.each do |offset|
      issued_at = Time.current.change(usec: 0)
      client = OidcClientRegistry.find!("core-app-jp")
      issuance = nil
      ClientOidcAuthorizationTransaction.stub(:database_now, issued_at) do
        ClientAuthAdmissionBinding.stub(:database_now, issued_at) do
          issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
            surface: "app", intent: "sign_in", params: {
              client_id: client.client_id,
              response_type: "code",
              scope: "openid profile",
              redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
              state: SecureRandom.urlsafe_base64(24),
              nonce: SecureRandom.urlsafe_base64(24),
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
            }, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
          ).handoff
        end
      end
      browser = open_session
      browser.host!(host)
      browser.https!
      entry_path = "/sign/in?#{Rack::Utils.build_query(entry_ref: issuance.reference, ri: "jp")}"
      attach_path = nil
      ClientOidcAuthorizationTransaction.stub(:database_now, issued_at) do
        ClientAuthAdmissionBinding.stub(:database_now, issued_at) do
          ClientAuthCeremonySession.stub(:database_now, issued_at) do
            browser.get(entry_path, headers: navigation)

            assert_equal 303, browser.response.status
            attach_path = browser.response.location
            # A12-5: a framed request is refused before the binding is attached.
            browser.get(attach_path, headers: navigation.merge("Sec-Fetch-Dest" => "iframe"))

            assert_equal 400, browser.response.status
            assert_nil ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference).auth_ceremony_session_id
            browser.get(attach_path, headers: navigation)

            assert_equal 303, browser.response.status
          end
        end
      end
      confirmation_location = browser.response.location
      binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
      before = [binding.reload.attributes, ClientAuthCeremonySession.find(binding.auth_ceremony_session_id).attributes]

      ClientOidcAuthorizationTransaction.stub(:database_now, issued_at + offset) do
        ClientAuthAdmissionBinding.stub(:database_now, issued_at + offset) do
          ClientAuthCeremonySession.stub(:database_now, issued_at + offset) do
            browser.get(attach_path, headers: navigation)
          end
        end
      end

      statuses << browser.response.status
      repeated_locations << browser.response.location
      expected_locations << confirmation_location

      assert_equal before,
                   [binding.reload.attributes,
                    ClientAuthCeremonySession.find(binding.auth_ceremony_session_id).attributes,]
    end

    assert_equal [303, 400, 400], statuses
    assert_equal expected_locations.first, repeated_locations.first
  end

  test "A12-3: Base confirmation repeats use the original 9/10/11 second issuance window" do
    statuses = []
    repeated_locations = []
    expected_locations = []
    offsets = [9.seconds, 10.seconds, 11.seconds]
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }

    offsets.each do |offset|
      nonce = SecureRandom.urlsafe_base64(32)
      issued_at = Time.current.change(usec: 0)
      issuance = nil
      client = OidcClientRegistry.find!("core-app-jp")
      ClientOidcAuthorizationTransaction.stub(:database_now, issued_at) do
        ClientAuthAdmissionBinding.stub(:database_now, issued_at) do
          issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
            surface: "app", intent: "sign_in", params: {
              client_id: client.client_id,
              response_type: "code",
              scope: "openid profile",
              redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
              state: SecureRandom.urlsafe_base64(24),
              nonce: SecureRandom.urlsafe_base64(24),
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
            }, base_browser_nonce: nonce, base_token: nil,
          ).handoff
        end
      end
      binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
      attached = nil
      ClientAuthAdmissionBinding.stub(:database_now, issued_at) do
        ClientAuthCeremonySession.stub(:database_now, issued_at) do
          attached, = ClientAuthCeremonySession.issue!
          binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
        end
      end
      browser = open_session
      browser.host!(host)
      browser.https!
      continuity = {
        "session_id" => SecureRandom.hex(16),
        "_csrf_token" => SecureRandom.urlsafe_base64(32),
        BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY => nonce,
      }
      cookie_request = ActionDispatch::TestRequest.create
      jar = ActionDispatch::Cookies::CookieJar.build(cookie_request, {})
      session_key = Rails.application.config.session_options.fetch(:key)
      jar.encrypted[session_key] = { value: continuity }
      store_raw_cookies(
        browser.cookies, "#{session_key}=#{Rack::Utils.escape(jar[session_key])}", URI.parse("https://#{host}/"),
      )
      confirmation_path = visa_app_ceremony_binding_confirmation_path(
        binding_ref: binding.confirmation_ref, ri: "jp",
      )
      before_confirmation = [binding.reload.attributes, attached.reload.attributes]
      foreign_browser = open_session
      foreign_browser.host!(host)
      foreign_browser.https!
      foreign_browser.get(confirmation_path, headers: navigation)

      assert_equal 400, foreign_browser.response.status
      assert_equal before_confirmation, [binding.reload.attributes, attached.reload.attributes]

      browser.get(confirmation_path, headers: navigation.merge("Sec-Fetch-Dest" => "iframe"))

      assert_equal 400, browser.response.status
      assert_framing_denied_with_application_policy(browser.response)
      assert_equal before_confirmation, [binding.reload.attributes, attached.reload.attributes]

      browser.get(confirmation_path)

      assert_equal 200, browser.response.status
      assert_framing_denied_with_application_policy(browser.response)
      assert_equal before_confirmation, [binding.reload.attributes, attached.reload.attributes]

      browser.head(confirmation_path, headers: navigation)

      assert_equal 400, browser.response.status
      assert_framing_denied_with_application_policy(browser.response)
      assert_equal before_confirmation, [binding.reload.attributes, attached.reload.attributes]

      ClientOidcAuthorizationTransaction.stub(:database_now, issued_at) do
        ClientAuthAdmissionBinding.stub(:database_now, issued_at) do
          ClientAuthCeremonySession.stub(:database_now, issued_at) do
            # This origin's service worker re-fetches navigations, which arrive as `empty`.
            browser.get(confirmation_path, headers: navigation.merge("Sec-Fetch-Dest" => "empty"))
          end
        end
      end

      assert_equal 303, browser.response.status, browser.response.body
      first_location = browser.response.location
      before = [binding.reload.attributes, attached.reload.attributes]

      ClientOidcAuthorizationTransaction.stub(:database_now, issued_at + offset) do
        ClientAuthAdmissionBinding.stub(:database_now, issued_at + offset) do
          ClientAuthCeremonySession.stub(:database_now, issued_at + offset) do
            browser.get(confirmation_path, headers: navigation)
          end
        end
      end

      statuses << browser.response.status
      repeated_locations << browser.response.location
      expected_locations << first_location

      assert_equal before, [binding.reload.attributes, attached.reload.attributes]
    end

    assert_equal [303, 400, 400], statuses
    assert_equal expected_locations.first, repeated_locations.first
  end

  test "A12-5: COM and ORG framed confirmations preserve live bindings" do
    [
      ["com", ENV.fetch("PUBLIC_VISA_CORPORATE_URL"), "core-com-jp", "visitor",
       VisitorAuthAdmissionBinding, VisitorAuthCeremonySession,],
      ["org", ENV.fetch("PUBLIC_VISA_STAFF_URL"), "core-org-jp", "operator",
       OperatorAuthAdmissionBinding, OperatorAuthCeremonySession,],
    ].each do |surface, host, client_id, realm, binding_class, ceremony_class|
      nonce = SecureRandom.urlsafe_base64(32)
      client = OidcClientRegistry.find!(client_id)
      issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
        surface: surface, intent: "sign_in", params: {
          client_id: client.client_id,
          response_type: "code",
          scope: "openid profile",
          redirect_uri: client.redirect_uris_by_realm.fetch(realm).first,
          state: SecureRandom.urlsafe_base64(24),
          nonce: SecureRandom.urlsafe_base64(24),
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
        }, base_browser_nonce: nonce, base_token: nil,
      ).handoff
      binding = binding_class.find_by!(entry_ref: issuance.reference)
      attached, = ceremony_class.issue!
      binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
      browser = open_session
      browser.host!(host)
      browser.https!
      cookie_request = ActionDispatch::TestRequest.create
      jar = ActionDispatch::Cookies::CookieJar.build(cookie_request, {})
      session_key = Rails.application.config.session_options.fetch(:key)
      jar.encrypted[session_key] = { value: {
        "session_id" => SecureRandom.hex(16),
        "_csrf_token" => SecureRandom.urlsafe_base64(32),
        BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY => nonce,
      } }
      store_raw_cookies(
        browser.cookies, "#{session_key}=#{Rack::Utils.escape(jar[session_key])}",
        URI.parse("https://#{host}/"),
      )
      path =
        if surface == "com"
          visa_com_ceremony_binding_confirmation_path(binding_ref: binding.confirmation_ref, ri: "jp")
        else
          visa_org_ceremony_binding_confirmation_path(binding_ref: binding.confirmation_ref, ri: "jp")
        end
      before = [binding.reload.attributes, attached.reload.attributes]
      browser.get(path, headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "iframe" })

      assert_equal 400, browser.response.status, surface
      assert_framing_denied_with_application_policy(browser.response)
      assert_equal before, [binding.reload.attributes, attached.reload.attributes]
    end
  end

  test "A12-4: an expired Auth attachment cannot mint a replacement confirmation hop" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    nonce = SecureRandom.urlsafe_base64(32)
    client = OidcClientRegistry.find!("core-app-jp")
    issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
      surface: "app", intent: "sign_in", params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      }, base_browser_nonce: nonce, base_token: nil,
    ).handoff
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    auth_browser = open_session
    auth_browser.host!(host)
    auth_browser.https!
    navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
    entry_path = "/sign/in?#{Rack::Utils.build_query(entry_ref: issuance.reference, ri: "jp")}"
    auth_browser.get(entry_path, headers: navigation)

    assert_equal 303, auth_browser.response.status
    auth_browser.get(auth_browser.response.location, headers: navigation)

    assert_equal 303, auth_browser.response.status
    attached = ClientAuthCeremonySession.find(binding.reload.auth_ceremony_session_id)
    confirmation_ref = binding.confirmation_ref
    before_count = ClientAuthCeremonySession.count
    attached.update_columns(expires_at: ClientAuthCeremonySession.database_now - 1.second)

    visa_browser = open_session
    visa_browser.host!(visa_host)
    visa_browser.https!
    continuity = {
      "session_id" => SecureRandom.hex(16),
      "_csrf_token" => SecureRandom.urlsafe_base64(32),
      BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY => nonce,
    }
    cookie_request = ActionDispatch::TestRequest.create
    jar = ActionDispatch::Cookies::CookieJar.build(cookie_request, {})
    session_key = Rails.application.config.session_options.fetch(:key)
    jar.encrypted[session_key] = { value: continuity }
    store_raw_cookies(
      visa_browser.cookies, "#{session_key}=#{Rack::Utils.escape(jar[session_key])}", URI.parse("https://#{visa_host}/"),
    )
    confirmation_path = visa_app_ceremony_binding_confirmation_path(
      binding_ref: confirmation_ref, ri: "jp",
    )
    visa_browser.get(confirmation_path, headers: navigation)

    assert_equal 400, visa_browser.response.status
    assert_equal before_count, ClientAuthCeremonySession.count
    assert_equal [confirmation_ref, attached.id, nil, nil],
                 [binding.reload.confirmation_ref, binding.auth_ceremony_session_id,
                  binding.base_confirmed_at, binding.redeemed_at,]
  end

  test "A12-3: redeemed entry repeats use the original 9/10/11 second issuance window" do
    statuses = []
    repeated_locations = []
    expected_repeat_location = nil
    offsets = [9.seconds, 10.seconds, 11.seconds]
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
    admission_store = Valkey::AuthState::OpaqueAdmissionStore.new

    offsets.each do |offset|
      issued_at = Time.current.change(usec: 0)
      client = OidcClientRegistry.find!("core-app-jp")
      issuance = nil
      ClientOidcAuthorizationTransaction.stub(:database_now, issued_at) do
        ClientAuthAdmissionBinding.stub(:database_now, issued_at) do
          issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
            surface: "app", intent: "sign_in", params: {
              client_id: client.client_id,
              response_type: "code",
              scope: "openid profile",
              redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
              state: SecureRandom.urlsafe_base64(24),
              nonce: SecureRandom.urlsafe_base64(24),
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
            }, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
          ).handoff
        end
      end
      browser = open_session
      browser.host!(host)
      browser.https!
      entry_path = "/sign/in?#{Rack::Utils.build_query(entry_ref: issuance.reference, ri: "jp")}"
      ClientOidcAuthorizationTransaction.stub(:database_now, issued_at) do
        ClientAuthAdmissionBinding.stub(:database_now, issued_at) do
          ClientAuthCeremonySession.stub(:database_now, issued_at) do
            browser.get(entry_path, headers: navigation)

            assert_equal 303, browser.response.status
            browser.get(browser.response.location, headers: navigation)

            assert_equal 303, browser.response.status
          end
        end
      end
      binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
      ClientAuthAdmissionBinding.stub(:database_now, issued_at) do
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
      end
      ClientAuthAdmissionBinding.stub(:database_now, issued_at) do
        ClientAuthCeremonySession.stub(:database_now, issued_at) do
          browser.get(entry_path, headers: navigation)
        end
      end

      assert_equal 303, browser.response.status
      clean_location = browser.response.location
      expected_repeat_location ||= clean_location

      assert_predicate binding.reload, :redeemed?
      ceremony_class = ClientAuthCeremonySession
      before = [
        binding.reload.attributes,
        ceremony_class.find(binding.admitted_auth_ceremony_session_id).attributes,
        ceremony_class.count,
        admission_store.read_reference!(reference: issuance.reference),
        browser.cookies.to_hash,
      ]

      ClientOidcAuthorizationTransaction.stub(:database_now, issued_at + offset) do
        ClientAuthAdmissionBinding.stub(:database_now, issued_at + offset) do
          ClientAuthCeremonySession.stub(:database_now, issued_at + offset) do
            browser.get(entry_path, headers: navigation)
          end
        end
      end

      statuses << browser.response.status
      repeated_locations << browser.response.location

      assert_equal before,
                   [binding.reload.attributes,
                    ceremony_class.find(binding.admitted_auth_ceremony_session_id).attributes,
                    ceremony_class.count,
                    admission_store.read_reference!(reference: issuance.reference),
                    browser.cookies.to_hash,]
      if offset == 9.seconds
        assert_equal clean_location, browser.response.location
      else
        assert_nil browser.response.location
      end
    end

    assert_equal [303, 400, 400], statuses
    assert_equal expected_repeat_location, repeated_locations.first
    assert_nil repeated_locations[1]
    assert_nil repeated_locations[2]
  end

  private

  def assert_framing_denied_with_application_policy(response)
    policy = response.headers.fetch("Content-Security-Policy")

    assert_includes policy, "frame-ancestors 'none'"
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "script-src 'self' 'strict-dynamic'"
  end
end
