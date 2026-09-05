# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySettingsPageCoverageTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  fixtures :visitors, :operators, :clients

  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "visitor browses and mutates identity telephones and telephone registration failures" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    host! host
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    _verification, raw_verification = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:com",
    )
    access_token = AuthenticationToken.encode(
      visitor,
      host: host,
      session_public_id: token.public_id,
      resource_type: "visitor",
      jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Accept" => "text/html,application/xhtml+xml",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    verified = VisitorTelephone.create!(
      visitor: visitor,
      number: "+819055510001",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    unverified = VisitorTelephone.create!(
      visitor: visitor,
      number: "+819055510002",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
    )
    extra = VisitorTelephone.create!(
      visitor: visitor,
      number: "+819055510003",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get base_com_identity_telephones_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_com_identity_telephone_url(verified.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    delete base_com_identity_telephone_url(extra.public_id, ri: "jp", host: host), headers: headers

    assert_response :redirect
    assert_nil VisitorTelephone.find_by(id: extra.id)

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_com_identity_telephones_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+819055510010" } },
           headers: headers
    end

    assert_response :redirect

    get new_base_com_identity_telephones_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_com_identity_telephones_registration_url(ri: "jp", host: host), headers: headers

    assert_response :redirect

    patch base_com_identity_telephones_registration_url(ri: "jp", host: host),
          params: { user_telephone: { pass_code: "123456" } },
          headers: headers

    assert_response :redirect

    TurnstileVerifierStub.challenge_response = { "success" => false }
    post base_com_identity_telephones_registration_url(ri: "jp", host: host),
         params: { user_telephone: { raw_number: "+819055510011" } },
         headers: headers

    assert_response :unprocessable_content

    TurnstileVerifierStub.challenge_response = { "success" => true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_com_identity_telephones_registration_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+819055510012" } },
           headers: headers
    end

    assert_response :redirect

    TurnstileVerifierStub.challenge_response = { "success" => false }
    patch base_com_identity_telephones_registration_url(ri: "jp", host: host),
          params: { user_telephone: { pass_code: "123456" } },
          headers: headers

    assert_response :unprocessable_content

    TurnstileVerifierStub.challenge_response = { "success" => true }
    patch base_com_identity_telephones_registration_url(ri: "jp", host: host),
          params: { user_telephone: { pass_code: "" } },
          headers: headers

    assert_response :unprocessable_content

    patch base_com_identity_telephones_registration_url(ri: "jp", host: host),
          params: { user_telephone: { pass_code: "000000" } },
          headers: headers

    assert_includes [302, 303, 422], response.status

    store = Rails.configuration.x.rate_limit.fetch(:store)
    6.times do
      store.increment(
        "rate-limit:telephone_verification:127.0.0.1",
        1,
        expires_in: 60.seconds,
      )
    end

    post base_com_identity_telephones_url(ri: "jp", host: host),
         params: { user_telephone: { raw_number: "+819055510013" } },
         headers: headers

    assert_equal 429, response.status

    assert_predicate unverified.reload, :present?
  end

  test "visitor browses identity secrets and email registration failure paths" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    host! host
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    _verification, raw_verification = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:com",
    )
    access_token = AuthenticationToken.encode(
      visitor,
      host: host,
      session_public_id: token.public_id,
      resource_type: "visitor",
      jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Accept" => "text/html,application/xhtml+xml",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    visitor_email = VisitorEmail.create!(
      visitor: visitor,
      address: "coverage-visitor-#{SecureRandom.hex(4)}@example.test",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
    )
    extra_visitor_email = VisitorEmail.create!(
      visitor: visitor,
      address: "coverage-visitor-extra-#{SecureRandom.hex(4)}@example.test",
      visitor_email_status_id: VisitorEmailStatus::UNVERIFIED,
      confirm_policy: true,
    )
    VisitorTelephone.create!(
      visitor: visitor,
      number: "+819055520001",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    secret = VisitorSecretCredential.create!(
      visitor: visitor,
      name: "Coverage secret",
      password: "a" * 32,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
      last_used_at: Time.current,
    )
    extra_secret = VisitorSecretCredential.create!(
      visitor: visitor,
      name: "Extra secret",
      password: "b" * 32,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
    )
    VisitorPasskey.create!(
      visitor: visitor,
      webauthn_id: "coverage_passkey_#{SecureRandom.hex(8)}",
      public_key: "public_key_#{SecureRandom.hex(8)}",
      sign_count: 0,
      description: "Coverage passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )

    get base_com_identity_secrets_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get base_com_identity_secret_url(secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_com_identity_secret_url(secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    get new_base_com_identity_secret_url(ri: "jp", host: host), headers: headers

    assert_response :success

    post base_com_identity_secrets_url(ri: "jp", host: host),
         params: { visitor_secret_credential: { name: "Created secret", enabled: "1" } },
         headers: headers

    assert_response :redirect

    post base_com_identity_secrets_url(ri: "jp", host: host),
         params: { visitor_secret_credential: { name: "", enabled: "1" } },
         headers: headers

    assert_includes [302, 303, 422], response.status

    # A failed challenge has to answer with the same 422 page the validation failure
    # answers with. Both surfaces are Inertia-only, so the shared guard cannot render
    # an ERB `:new` here -- doing so raised ActionView::MissingTemplate.
    TurnstileVerifierStub.challenge_response = { "success" => false }
    post base_com_identity_secrets_url(ri: "jp", host: host),
         params: { visitor_secret_credential: { name: "Turnstile blocked secret", enabled: "1" } },
         headers: headers

    assert_response :unprocessable_content
    assert_not VisitorSecretCredential.exists?(name: "Turnstile blocked secret")
    TurnstileVerifierStub.challenge_response = { "success" => true }

    delete base_com_identity_secret_url(extra_secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :redirect

    token.update!(last_step_up_scope: "settings_email")
    get base_com_identity_emails_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_com_identity_email_url(visitor_email.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    patch base_com_identity_email_url(visitor_email.public_id, ri: "jp", host: host),
          params: { visitor_email: { promotional: "0", notifiable: "1" } },
          headers: headers

    assert_includes [302, 303, 422], response.status

    TurnstileVerifierStub.challenge_response = { "success" => false }
    patch base_com_identity_email_url(visitor_email.public_id, ri: "jp", host: host),
          params: { visitor_email: { promotional: "0", notifiable: "1" } },
          headers: headers

    assert_response :unprocessable_content
    TurnstileVerifierStub.challenge_response = { "success" => true }

    delete base_com_identity_email_url(extra_visitor_email.public_id, ri: "jp", host: host), headers: headers

    assert_includes [302, 303], response.status

    get new_base_com_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_com_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :redirect

    patch base_com_identity_emails_registration_url(ri: "jp", host: host),
          params: { visitor_email: { pass_code: "" } },
          headers: headers

    assert_response :redirect

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_com_identity_emails_registration_url(ri: "jp", host: host),
           params: { visitor_email: { address: "coverage-new-#{SecureRandom.hex(4)}@example.test" } },
           headers: headers
    end

    assert_response :redirect

    patch base_com_identity_emails_registration_url(ri: "jp", host: host),
          params: { visitor_email: { pass_code: "" } },
          headers: headers

    assert_response :unprocessable_content

    patch base_com_identity_emails_registration_url(ri: "jp", host: host),
          params: { visitor_email: { pass_code: "000000" } },
          headers: headers

    assert_includes [302, 303, 422], response.status
  end

  test "operator browses identity sessions secrets and telephones" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! host
    operator = operators(:one)
    token = OperatorToken.create!(
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    _verification, raw_verification = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    access_token = AuthenticationToken.encode(
      operator,
      host: host,
      session_public_id: token.public_id,
      resource_type: "operator",
      jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Accept" => "text/html,application/xhtml+xml",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    secret = OperatorSecretCredential.create!(
      staff: operator,
      name: "Org coverage secret",
      password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
      last_used_at: Time.current,
    )
    extra_secret = OperatorSecretCredential.create!(
      staff: operator,
      name: "Org extra secret",
      password_digest: "digest2",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
    OperatorPasskey.create!(
      staff: operator,
      webauthn_id: "org_coverage_passkey_#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key_#{SecureRandom.hex(8)}",
      description: "Coverage passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    telephone = OperatorTelephone.create!(
      staff: operator,
      number: "+819066610001",
      staff_telephone_status_id: OperatorTelephoneStatus::VERIFIED,
    )
    extra_telephone = OperatorTelephone.create!(
      staff: operator,
      number: "+819066610002",
      staff_telephone_status_id: OperatorTelephoneStatus::UNVERIFIED,
    )

    get base_org_identity_sessions_url(ri: "jp", host: host), headers: headers

    assert_includes [200, 302, 303], response.status

    other_session = OperatorToken.where(staff: operator).where.not(id: token.id).where(
      "discarded_at > ?",
      Time.current,
    ).first
    if other_session
      get base_org_identity_session_url(other_session.public_id, ri: "jp", host: host), headers: headers

      assert_includes [200, 302, 303, 406], response.status

      delete base_org_identity_session_url(other_session.public_id, ri: "jp", host: host), headers: headers

      assert_includes [200, 302, 303], response.status
    end

    get base_org_identity_secrets_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get base_org_identity_secret_url(secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_org_identity_secret_url(secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    get new_base_org_identity_secret_url(ri: "jp", host: host), headers: headers

    assert_response :success

    post base_org_identity_secrets_url(ri: "jp", host: host),
         params: { staff_secret_credential: { name: "Created org secret", enabled: "1" } },
         headers: headers

    assert_includes [302, 303, 422], response.status

    TurnstileVerifierStub.challenge_response = { "success" => false }
    post base_org_identity_secrets_url(ri: "jp", host: host),
         params: { staff_secret_credential: { name: "Turnstile blocked org secret", enabled: "1" } },
         headers: headers

    assert_response :unprocessable_content
    assert_not OperatorSecretCredential.exists?(name: "Turnstile blocked org secret")
    TurnstileVerifierStub.challenge_response = { "success" => true }

    patch base_org_identity_secret_url(secret.public_id, ri: "jp", host: host),
          params: { staff_secret_credential: { name: "Renamed org secret", enabled: "1" } },
          headers: headers

    assert_response :redirect

    delete base_org_identity_secret_url(extra_secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :redirect

    token.update!(last_step_up_scope: "settings_telephone")
    get base_org_identity_telephones_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_org_identity_telephone_url(telephone.id, ri: "jp", host: host), headers: headers

    assert_response :success

    get new_base_org_identity_telephone_url(ri: "jp", host: host), headers: headers

    assert_response :success

    post base_org_identity_telephones_url(ri: "jp", host: host),
         params: { staff_telephone: { raw_number: "" } },
         headers: headers

    assert_response :unprocessable_content

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_org_identity_telephones_url(ri: "jp", host: host),
           params: { staff_telephone: { raw_number: "+819066610099" } },
           headers: headers
    end

    assert_includes [302, 303, 422], response.status

    delete base_org_identity_telephone_url(extra_telephone.id, ri: "jp", host: host), headers: headers

    assert_response :redirect

    operator_email = OperatorEmail.create!(
      staff: operator,
      address: "org-coverage-#{SecureRandom.hex(4)}@example.test",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
    extra_operator_email = OperatorEmail.create!(
      staff: operator,
      address: "org-coverage-extra-#{SecureRandom.hex(4)}@example.test",
      staff_email_status_id: OperatorEmailStatus::UNVERIFIED,
    )

    token.update!(last_step_up_scope: "settings_email")
    get base_org_identity_emails_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_org_identity_email_url(operator_email.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    patch base_org_identity_email_url(operator_email.public_id, ri: "jp", host: host),
          params: { staff_email: { promotional: "0", notifiable: "1" } },
          headers: headers

    assert_includes [302, 303, 422], response.status

    TurnstileVerifierStub.challenge_response = { "success" => false }
    patch base_org_identity_email_url(operator_email.public_id, ri: "jp", host: host),
          params: { staff_email: { promotional: "0", notifiable: "1" } },
          headers: headers

    assert_response :unprocessable_content
    TurnstileVerifierStub.challenge_response = { "success" => true }

    delete base_org_identity_email_url(extra_operator_email.public_id, ri: "jp", host: host), headers: headers

    assert_includes [302, 303], response.status

    get new_base_org_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_org_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :redirect

    TurnstileVerifierStub.challenge_response = { "success" => false }
    post base_org_identity_emails_registration_url(ri: "jp", host: host),
         params: { staff_email: { raw_address: "org-coverage-#{SecureRandom.hex(4)}@example.test" } },
         headers: headers

    assert_response :unprocessable_content

    TurnstileVerifierStub.challenge_response = { "success" => true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_org_identity_emails_registration_url(ri: "jp", host: host),
           params: { staff_email: { raw_address: "org-coverage-#{SecureRandom.hex(4)}@example.test" } },
           headers: headers
    end

    assert_includes [302, 303, 422], response.status

    token.update!(last_step_up_scope: "settings_telephone")
    get new_base_org_identity_telephones_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_org_identity_telephones_registration_url(ri: "jp", host: host), headers: headers

    assert_includes [302, 303], response.status
  end

  test "client browses identity secrets and telephones" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    BaseSelectorAuthority.prepare(surface: :app, principal: user, session: token)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    access_token = AuthenticationToken.encode(
      user,
      host: host,
      session_public_id: token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Accept" => "text/html,application/xhtml+xml",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    ClientEmail.create!(
      user: user,
      address: "app-coverage-#{SecureRandom.hex(4)}@example.test",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      confirm_policy: true,
    )
    secret = ClientSecretCredential.create!(
      user: user,
      name: "App coverage secret",
      password: "a" * 32,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
      user_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
      last_used_at: Time.current,
    )
    extra_secret = ClientSecretCredential.create!(
      user: user,
      name: "App extra secret",
      password: "b" * 32,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
      user_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
    )
    ClientPasskey.create!(
      user: user,
      webauthn_id: "app_coverage_passkey_#{SecureRandom.hex(8)}",
      public_key: "public_key_#{SecureRandom.hex(8)}",
      sign_count: 0,
      description: "Coverage passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    telephone = ClientTelephone.create!(
      user: user,
      number: "+819077710001",
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    extra_telephone = ClientTelephone.create!(
      user: user,
      number: "+819077710002",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
    )

    get base_app_identity_secrets_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get base_app_identity_secret_url(secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_app_identity_secret_url(secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    patch base_app_identity_secret_url(secret.public_id, ri: "jp", host: host),
          params: { user_secret_credential: { name: "Renamed app secret", enabled: "1" } },
          headers: headers

    assert_includes [302, 303, 422], response.status

    delete base_app_identity_secret_url(extra_secret.public_id, ri: "jp", host: host), headers: headers

    assert_includes [302, 303], response.status

    token.update!(last_step_up_scope: "settings_telephone")
    get base_app_identity_telephones_url(ri: "jp", host: host), headers: headers

    assert_includes [200, 302, 303], response.status

    get edit_base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: host), headers: headers

    assert_includes [200, 302, 303, 406], response.status

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_app_identity_telephones_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+819077710099" } },
           headers: headers
    end

    assert_includes [302, 303, 422], response.status

    delete base_app_identity_telephone_url(extra_telephone.public_id, ri: "jp", host: host), headers: headers

    assert_includes [302, 303], response.status
  end
end
