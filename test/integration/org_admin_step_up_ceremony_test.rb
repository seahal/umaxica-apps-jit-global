# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

# The support mutation case uses a pre-existing Base token, opaque admission/result transport
# and real WebAuthn assertions with separate Base/Auth cookie jars. It does not prove root login.
# Negative cases use synthetic verified evidence to isolate authority and transport checks.
class OrgAdminStepUpCeremonyTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens, :clients

  setup do
    https!
    @base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    @operator = operators(:one)
    AuthenticationSessionRevoker.tokens_for(@operator).find_each(&:revoke!)
    @token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: OperatorToken.database_now + 1.hour,
    )
    @passkey = OperatorPasskey.create!(
      staff: @operator, webauthn_id: "org_admin_ceremony_#{SecureRandom.hex(8)}", external_id: SecureRandom.uuid,
      public_key: "org-admin-ceremony-public-key", sign_count: 0, description: "Admin ceremony passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    @client = clients(:one)
    AuthenticationSessionRevoker.tokens_for(@client).find_each(&:revoke!)
    # The compliance row normally comes from migration 20260926130000 (365 days, decided 2026-09-26);
    # a schema-only load skips that insert, so the test ensures it with the same value.
    ChronicleRetentionPolicy.find_or_create_by!(code: "compliance") do |policy|
      policy.name = "Compliance"
      policy.duration_days = 365
      policy.permanent = false
    end
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "support revocation passes opaque admission, real signature, Base completion and business authorization" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    target_session = ClientToken.create!(authentication_epoch: 0, user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    fake = WebAuthn::FakeClient.new("https://#{@auth_host}", encoding: :base64url)
    registration = fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: @auth_host, allowed_origins: [fake.origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    passkey = @operator.staff_passkeys.create!(
      webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    access = AuthenticationToken.encode(
      @operator, host: @base_host, session_public_id: @token.public_id,
                 resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    base_headers = { "Authorization" => "Bearer #{access}", "Host" => @base_host, "Client-Agent" => "Mozilla/5.0" }
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_root = @token.reload
    rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
    rp_record = OpOrgGrant.find_by(
      device_session_id: rp_root.device_session_id,
      oidc_client_id: rp_client.client_id,
      revoked_at: nil,
    )
    rp_record ||= OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: rp_root, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: OpOrgGrant.database_now,
      refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
    )
    rp_access = AuthenticationTokenService.encode(
      @operator, host: @base_host, resource_type: "operator", session_public_id: rp_root.public_id,
                 base_session_public_id: rp_root.public_id, oidc_sid: rp_record.public_id, oidc_jti: rp_record.oidc_jti,
                 expires_at: OpOrgGrant.database_now + 10.minutes, scopes: %w(openid profile),
                 issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: rp_client.client_id,
    )
    base_headers["Cookie"] = "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access)}; " \
                             "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}; " \
                             "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_record.issue_refresh_token!)}"
    screen_path = new_base_org_support_client_revocation_path(@client.public_id, ri: "jp")
    get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host), headers: base_headers

    assert_response :redirect
    assert_equal "support_session_revoke", Rack::Utils.parse_query(URI.parse(response.location).query)["scope"]

    get response.location, headers: base_headers

    assert_response :success

    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    form = props.fetch("form")
    post base_org_verification_url(ri: "jp", host: @base_host),
         params: { scope: form.fetch("scope"), pt: form.fetch("pt") }, headers: base_headers
    session_cookie_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    session_cookie_value = response.cookies[session_cookie_key] || cookies[session_cookie_key]
    if session_cookie_value.present?
      base_headers["Cookie"] += "; #{session_cookie_key}=#{Rack::Utils.escape(session_cookie_value)}"
    end

    assert_response :see_other

    gateway = URI.parse(response.location)
    jump_payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)
    auth_location = jump_payload.fetch("url")
    reference = Rack::Utils.parse_query(URI.parse(auth_location).query).fetch("entry_ref")
    auth_browser = open_session
    auth_browser.https!
    auth_browser.host!(@auth_host)
    auth_browser.get(auth_location)

    admission_form = Nokogiri::HTML(auth_browser.response.body).at_css("form")
    csrf = admission_form.at_css('input[name="authenticity_token"]')["value"]
    auth_browser.post(
      admission_form["action"], params: {
        entry_ref: reference, authenticity_token: csrf,
      },
    )

    assert_equal 303, auth_browser.response.status
    confirmation = URI.parse(auth_browser.response.location)
    get confirmation.request_uri, headers: base_headers

    binding_form = response.parsed_body.at_css("form")
    binding_fields = binding_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
    post binding_form["action"], params: binding_fields,
                                 headers: base_headers.merge(
                                   "Origin" => "https://#{@base_host}",
                                   "Sec-Fetch-Site" => "same-origin",
                                 )

    auth_browser.get(response.location)
    continuation = auth_browser.response.parsed_body.at_css("form")
    continuation_fields = continuation.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
    auth_browser.post(
      continuation["action"], params: continuation_fields,
                              headers: { "Origin" => "https://#{@auth_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    auth_browser.get(new_auth_org_verification_passkey_path(ri: "jp"))

    page = Nokogiri::HTML(auth_browser.response.body)
    panel = JSON.parse(page.at_css("script[data-page='app']").text).fetch("props").fetch("panel")
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    auth_browser.post(
      panel.fetch("options_url"), params: { "cf-turnstile-response" => "test-only" },
                                  headers: { "X-CSRF-Token" => csrf }, as: :json,
    )

    assert_equal 200, auth_browser.response.status

    options = auth_browser.response.parsed_body
    assertion = fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 2)
    auth_browser.post(
      panel.fetch("verification_url"),
      params: { credential: assertion, challenge_id: options.fetch("challenge_id") },
      headers: { "X-CSRF-Token" => csrf }, as: :json,
    )

    assert_equal 200, auth_browser.response.status
    assert_nil @token.reload.last_step_up_at

    auth_browser.get(auth_browser.response.parsed_body.fetch("redirect_url"))
    handoff_form = Nokogiri::HTML(auth_browser.response.body).at_css("form")
    auth_browser.post(
      handoff_form["action"], params: {
        authenticity_token: handoff_form.at_css('input[name="authenticity_token"]')["value"],
      },
    )

    assert_equal 303, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationCookieName.access]
    assert_nil auth_browser.cookies[AuthenticationCookieName.refresh]
    completion = URI.parse(auth_browser.response.location)
    get completion.request_uri, headers: base_headers
    result_form = response.parsed_body.at_css("form")
    transaction_ref = result_form.at_css('input[name="transaction_ref"]')["value"]
    transaction = OperatorStepUpCeremonyTransaction.find_by!(transaction_id: transaction_ref)

    assert_equal passkey.external_id, transaction.verified_credential_ref

    fields = result_form.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
    post result_form["action"], params: fields,
                                headers: base_headers.merge(
                                  "Origin" => "https://#{@base_host}",
                                  "Sec-Fetch-Site" => "same-origin",
                                )

    assert_response :see_other
    assert_equal screen_path, URI.parse(response.location).request_uri
    assert_equal "consumed", transaction.reload.status
    assert_equal transaction.verified_at, @token.reload.last_step_up_at
    assert_equal "support_session_revoke", @token.last_step_up_scope
    assert_equal "step_up:org", @token.last_step_up_audience
    assert_equal @token.public_id, @token.last_step_up_session_public_id
    assert_equal "passkey", @token.last_step_up_method
    assert_equal "aal1", @token.last_step_up_aal

    get response.location, headers: base_headers

    assert_response :ok

    confirmation = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    operation_id = confirmation.fetch("fields").find { |field| field["name"] == "operation_id" }.fetch("value")
    post base_org_support_client_revocations_url(@client.public_id, host: @base_host),
         params: { reason_code: "security_incident", operation_id: operation_id }, headers: base_headers

    assert_response :see_other
    assert_predicate target_session.reload, :revoked?

    chronicle = Chronicle.find_by!(event_uuid: operation_id)

    assert_equal ["support.session.revoked", "succeeded"], [chronicle.action, chronicle.result]
    assert_equal ["Operator", @operator.id], [chronicle.actor_type, chronicle.actor_id]

    replacement_session = ClientToken.create!(authentication_epoch: 0, user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    OperatorCapabilityGrant.find_by!(
      operator: @operator, capability: OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,
    ).revoke!(by: operators(:two), reason_code: "duty_ended")
    event = @token.last_step_up_at

    assert_no_difference -> { Chronicle.where(action: "support.session.revoked", result: "succeeded").count } do
      post base_org_support_client_revocations_url(@client.public_id, host: @base_host),
           params: { reason_code: "security_incident", operation_id: SecureRandom.uuid },
           headers: base_headers, as: :json
    end
    assert_response :forbidden
    assert_predicate replacement_session.reload, :currently_usable?
    assert_equal event, @token.reload.last_step_up_at
  end

  test "another canonical scope does not satisfy Support revocation" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    requirement = StepUpRequirement.new(
      step_up_required: true,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      scope: "session_revoke_all", allowed_methods: [:passkey], purpose: "step_up",
      audience: "step_up:org", session_binding: @token.public_id, token_binding: @token.public_id,
      require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: @operator.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: @operator,
      token: @token,
      requirement: requirement,
      return_to: "/identity/sessions",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: @token,
    ).transaction
    # Synthetic evidence isolates the scope consumer; the success case verifies actual signatures.
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: OperatorStepUpCeremonyTransaction.database_now, verified_credential_ref: @passkey.external_id,
    )
    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @operator, token: @token, transaction: transaction, requirement: requirement, raw_result: result.code,
    )
    access = AuthenticationToken.encode(
      @operator, host: @base_host, session_public_id: @token.public_id,
                 resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    headers = { "Authorization" => "Bearer #{access}", "Host" => @base_host, "Client-Agent" => "Mozilla/5.0" }
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_root = @token.reload
    rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
    rp_record = OpOrgGrant.find_by(
      device_session_id: rp_root.device_session_id,
      oidc_client_id: rp_client.client_id,
      revoked_at: nil,
    )
    rp_record ||= OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: rp_root, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: OpOrgGrant.database_now,
      refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
    )
    rp_access = AuthenticationTokenService.encode(
      @operator, host: @base_host, resource_type: "operator", session_public_id: rp_root.public_id,
                 base_session_public_id: rp_root.public_id, oidc_sid: rp_record.public_id, oidc_jti: rp_record.oidc_jti,
                 expires_at: OpOrgGrant.database_now + 10.minutes, scopes: %w(openid profile),
                 issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: rp_client.client_id,
    )
    headers["Cookie"] = "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access)}; " \
                        "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}; " \
                        "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_record.issue_refresh_token!)}"
    get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host), headers: headers

    assert_response :redirect
    assert_includes response.location, "scope=support_session_revoke"
    assert_equal "session_revoke_all", @token.reload.last_step_up_scope
    assert_equal "consumed", transaction.reload.status
  end

  test "an Emergency session cannot start the ceremony for an administrative scope" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @token.update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    access = AuthenticationToken.encode(
      @operator, host: @base_host, session_public_id: @token.public_id,
                 resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    headers = { "Authorization" => "Bearer #{access}", "Host" => @base_host, "Client-Agent" => "Mozilla/5.0" }
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_root = @token.reload
    rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
    rp_record = OpOrgGrant.find_by(
      device_session_id: rp_root.device_session_id,
      oidc_client_id: rp_client.client_id,
      revoked_at: nil,
    )
    rp_record ||= OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: rp_root, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: OpOrgGrant.database_now,
      refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
    )
    rp_access = AuthenticationTokenService.encode(
      @operator, host: @base_host, resource_type: "operator", session_public_id: rp_root.public_id,
                 base_session_public_id: rp_root.public_id, oidc_sid: rp_record.public_id, oidc_jti: rp_record.oidc_jti,
                 expires_at: OpOrgGrant.database_now + 10.minutes, scopes: %w(openid profile),
                 issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: rp_client.client_id,
    )
    headers["Cookie"] = "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access)}; " \
                        "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}; " \
                        "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_record.issue_refresh_token!)}"

    assert_no_difference -> { OperatorStepUpCeremonyTransaction.count } do
      get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host), headers: headers
    end

    assert_response :forbidden
  end

  %i(session surface).each do |mismatch|
    test "opaque result for another #{mismatch} cannot complete the Base browser transaction" do
      [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
       OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
        OperatorCapabilityGrant.create!(
          operator: @operator, origin: "bootstrap", capability: capability,
          reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
        )
      end
      BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
      BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
      access = AuthenticationToken.encode(
        @operator, host: @base_host, session_public_id: @token.public_id,
                   resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
      )
      headers = { "Authorization" => "Bearer #{access}", "Host" => @base_host, "Client-Agent" => "Mozilla/5.0" }
      rp_client = OidcClientRegistry.find!("base-org-ww")
      rp_root = @token.reload
      rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
      rp_record = OpOrgGrant.find_by(
        device_session_id: rp_root.device_session_id,
        oidc_client_id: rp_client.client_id,
        revoked_at: nil,
      )
      rp_record ||= OpOrgGrant.create!(
        authentication_epoch: 0,
        operator_token: rp_root, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: OpOrgGrant.database_now,
        refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
      )
      rp_access = AuthenticationTokenService.encode(
        @operator,
        host: @base_host,
        resource_type: "operator",
        session_public_id: rp_root.public_id,
        base_session_public_id: rp_root.public_id,
        oidc_sid: rp_record.public_id,
        oidc_jti: rp_record.oidc_jti,
        expires_at: OpOrgGrant.database_now + 10.minutes,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(rp_client),
        audiences: [rp_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"),
        client_id: rp_client.client_id,
      )
      headers["Cookie"] = "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access)}; " \
                          "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}; " \
                          "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_record.issue_refresh_token!)}"
      screen = new_base_org_support_client_revocation_path(@client.public_id, ri: "jp")
      get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host), headers: headers
      get response.location, headers: headers
      form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
      post base_org_verification_url(ri: "jp", host: @base_host),
           params: { scope: form.fetch("scope"), pt: form.fetch("pt") }, headers: headers
      session_cookie_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      session_cookie_value = response.cookies[session_cookie_key] || cookies[session_cookie_key]
      if session_cookie_value.present?
        headers["Cookie"] += "; #{session_cookie_key}=#{Rack::Utils.escape(session_cookie_value)}"
      end

      assert_response :see_other

      record = OperatorStepUpSession.find_by!(staff_token_id: @token.id)
      own = OperatorStepUpCeremonyTransaction.find_by!(transaction_id: record.step_up_ceremony_transaction_ref)
      own_binding = OperatorAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: own.id)
      attached, raw_sid = OperatorAuthCeremonySession.issue!
      own_binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
      own_binding.confirm_base!(base_token: @token, browser_digest: own_binding.base_browser_digest)
      ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
        step_up_ceremony_transaction_ref: own.transaction_id,
      )
      own_binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)

      if mismatch == :session
        foreign_actor = @operator
        foreign_token = OperatorToken.create!(authentication_epoch: 0, staff: @operator)
        reference = @passkey.external_id
        foreign_requirement = StepUpRequirement.new(
          step_up_required: true,
          phishing_resistant_required: false,
          user_verification_required: false,
          full_reauthentication_required: false,
          scope: "support_session_revoke", allowed_methods: [:passkey], purpose: "step_up",
          audience: "step_up:org", session_binding: foreign_token.public_id, token_binding: foreign_token.public_id,
          require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: @operator.public_id,
          resource_ref: nil, tenant_ref: nil,
        )
        foreign = BaseStepUpAdmissionIssuer.call!(
          actor: foreign_actor, token: foreign_token,
          requirement: foreign_requirement, return_to: screen,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: foreign_token,
        ).transaction
        foreign_ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
          admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: foreign.transaction_id,
        )
      else
        foreign_actor = @client
        foreign_token = ClientToken.create!(authentication_epoch: 0, user: @client)
        reference = @client.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public").public_id
        foreign_requirement = StepUpRequirement.new(
          step_up_required: true,
          phishing_resistant_required: false,
          user_verification_required: false,
          full_reauthentication_required: false,
          scope: "session_revoke_all", allowed_methods: [:passkey], purpose: "step_up",
          audience: "step_up:app", session_binding: foreign_token.public_id, token_binding: foreign_token.public_id,
          require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: foreign_actor.public_id,
          resource_ref: nil, tenant_ref: nil,
        )
        foreign = BaseStepUpAdmissionIssuer.call!(
          actor: foreign_actor, token: foreign_token,
          requirement: foreign_requirement, return_to: "/identity/sessions",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: foreign_token,
        ).transaction
        foreign_ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
          admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: foreign.transaction_id,
        )
      end
      # Synthetic evidence isolates cross-ticket transport, not signature verification.
      foreign.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
        verified_at: foreign.class.database_now, verified_credential_ref: reference,
      )
      foreign_result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: foreign, ceremony_session_ref: foreign_ceremony.id.to_s,
      )
      post base_org_verification_completion_url(ri: "jp", host: @base_host),
           params: { transaction_ref: own.transaction_id, result_ref: foreign_result.reference },
           headers: headers.merge("Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin")

      assert_response :bad_request
      assert_nil @token.reload.last_step_up_at
      assert_nil foreign_token.reload.last_step_up_at
      assert_equal "pending", own.reload.status
      assert_equal "verified", foreign.reload.status
      assert_not_predicate foreign_ceremony.reload, :completed?

      own.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
        verified_at: OperatorStepUpCeremonyTransaction.database_now, verified_credential_ref: @passkey.external_id,
      )
      own_result = BaseAuthAdmissionCoordinator.issue_result!(transaction: own, ceremony_session_ref: ceremony.id.to_s)
      post base_org_verification_completion_url(ri: "jp", host: @base_host),
           params: { transaction_ref: own.transaction_id, result_ref: own_result.reference },
           headers: headers.merge("Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin")

      assert_response :see_other
      assert_equal screen, URI.parse(response.location).request_uri
      event = @token.reload.last_step_up_at

      assert_equal own.reload.verified_at, event
      assert_equal "consumed", own.status
      assert_predicate ceremony.reload, :completed?

      travel 1.second do
        post base_org_verification_completion_url(ri: "jp", host: @base_host),
             params: { transaction_ref: own.transaction_id, result_ref: own_result.reference },
             headers: headers.merge("Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin")

        assert_response :see_other
        assert_equal event, @token.reload.last_step_up_at
        assert_equal "consumed", own.reload.status
        assert_equal "verified", foreign.reload.status
      end
    end
  end

  [-1, 0, 1].each do |microseconds|
    test "Support confirmation evaluates canonical freshness #{microseconds} microseconds from expiry" do
      [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
       OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
        OperatorCapabilityGrant.create!(
          operator: @operator, origin: "bootstrap", capability: capability,
          reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 2.days.from_now,
        )
      end
      BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
      BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
      requirement = StepUpRequirement.new(
        step_up_required: true,
        phishing_resistant_required: false,
        user_verification_required: false,
        full_reauthentication_required: false,
        scope: "support_session_revoke", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:org", session_binding: @token.public_id, token_binding: @token.public_id,
        require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: @operator.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      screen = new_base_org_support_client_revocation_path(@client.public_id, ri: "jp")
      transaction = BaseStepUpAdmissionIssuer.call!(
        actor: @operator, token: @token, requirement: requirement,
        return_to: screen, base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: @token,
      ).transaction
      # Synthetic evidence isolates freshness consumption; the success case verifies signatures.
      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
        verified_at: OperatorStepUpCeremonyTransaction.database_now, verified_credential_ref: @passkey.external_id,
      )
      ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @operator, token: @token, transaction: transaction, requirement: requirement, raw_result: result.code,
      )
      event = @token.reload.last_step_up_at
      travel_to(event + requirement.ttl + Rational(microseconds, 1_000_000), with_usec: true) do
        access = AuthenticationToken.encode(
          @operator, host: @base_host, session_public_id: @token.public_id,
                     resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
        )
        boundary_headers = {
          "Authorization" => "Bearer #{access}",
          "Host" => @base_host,
          "Client-Agent" => "Mozilla/5.0",
        }
        rp_client = OidcClientRegistry.find!("base-org-ww")
        rp_root = @token.reload
        rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
        rp_record = OpOrgGrant.find_by(
          device_session_id: rp_root.device_session_id,
          oidc_client_id: rp_client.client_id,
          revoked_at: nil,
        )
        rp_record ||= OpOrgGrant.create!(
          authentication_epoch: 0,
          operator_token: rp_root, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: OpOrgGrant.database_now,
          refresh_token_expires_at: 10.minutes.from_now,
        )
        rp_access = AuthenticationTokenService.encode(
          @operator,
          host: @base_host,
          resource_type: "operator",
          session_public_id: rp_root.public_id,
          base_session_public_id: rp_root.public_id,
          oidc_sid: rp_record.public_id,
          oidc_jti: rp_record.oidc_jti,
          expires_at: 10.minutes.from_now,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(rp_client),
          audiences: [rp_client.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
          subject: OidcSubject.for(@operator, resource_type: "operator"),
          client_id: rp_client.client_id,
        )
        rp_refresh_cookie = Rack::Utils.escape(rp_record.issue_refresh_token!)
        rp_access_cookie = Rack::Utils.escape(rp_access)
        boundary_headers["Cookie"] = "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{rp_access_cookie}; " \
                                     "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{rp_refresh_cookie}"
        get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host),
            headers: boundary_headers

        if microseconds < 0
          assert_response :ok
        else
          assert_response :redirect
          assert_includes response.location, "scope=support_session_revoke"
        end

        assert_equal event, @token.reload.last_step_up_at
        assert_equal "consumed", transaction.reload.status
      end
    end
  end

  test "the return target cannot be forged or reused for a different scope" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    access = AuthenticationToken.encode(
      @operator, host: @base_host, session_public_id: @token.public_id,
                 resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    base_headers = { "Authorization" => "Bearer #{access}", "Host" => @base_host, "Client-Agent" => "Mozilla/5.0" }
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_root = @token.reload
    rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
    rp_record = OpOrgGrant.find_by(
      device_session_id: rp_root.device_session_id,
      oidc_client_id: rp_client.client_id,
      revoked_at: nil,
    )
    rp_record ||= OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: rp_root, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: OpOrgGrant.database_now,
      refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
    )
    rp_access = AuthenticationTokenService.encode(
      @operator, host: @base_host, resource_type: "operator", session_public_id: rp_root.public_id,
                 base_session_public_id: rp_root.public_id, oidc_sid: rp_record.public_id, oidc_jti: rp_record.oidc_jti,
                 expires_at: OpOrgGrant.database_now + 10.minutes, scopes: %w(openid profile),
                 issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: rp_client.client_id,
    )
    base_headers["Cookie"] = "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access)}; " \
                             "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}; " \
                             "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_record.issue_refresh_token!)}"

    get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host), headers: base_headers
    signed_pt = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("pt")

    assert_no_difference -> { OperatorStepUpCeremonyTransaction.count } do
      get base_org_verification_url(scope: "support_session_revoke", pt: "forged-target", ri: "jp", host: @base_host),
          headers: base_headers

      assert_response :bad_request

      get base_org_verification_url(scope: "session_revoke_all", pt: signed_pt, ri: "jp", host: @base_host),
          headers: base_headers

      assert_response :bad_request

      [["support_session_revoke", "forged-target"], ["session_revoke_all", signed_pt]].each do |scope, target|
        post base_org_verification_url(ri: "jp", host: @base_host),
             params: { scope: scope, pt: target }, headers: base_headers
        session_cookie_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
        session_cookie_value = response.cookies[session_cookie_key] || cookies[session_cookie_key]
        if session_cookie_value.present?
          base_headers["Cookie"] += "; #{session_cookie_key}=#{Rack::Utils.escape(session_cookie_value)}"
        end

        assert_response :bad_request
      end
    end
  end
end
