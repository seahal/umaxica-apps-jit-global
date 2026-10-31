# frozen_string_literal: true

require "test_helper"

class BasePasskeyMutationStepUpTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  skip_transactional_tests_for_database :op_base_app
  skip_transactional_tests_for_database :op_base_org

  setup do
    @op_actors = []
  end

  teardown do
    @op_actors.each do |actor, token, existing_transaction_ids|
      if actor.is_a?(Client)
        tokens = ClientToken.where(id: token.id)
        transactions = ClientStepUpCeremonyTransaction.where(actor_ref: actor.public_id)
        transactions = transactions.where.not(id: existing_transaction_ids)
        ClientStepUpSession.where(user_token_id: tokens.select(:id)).delete_all
        ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transactions.select(:id)).delete_all
        ClientAuthCeremonySession.where(
          step_up_ceremony_transaction_ref: transactions.select(:transaction_id),
        ).delete_all
        transactions.delete_all
        OpAppGrant.where(client_token_id: tokens.select(:id)).includes(:logout_hint).destroy_all
        ClientDeviceSession.where(id: token.device_session_id).update_all(current_refresh_token_id: nil)
        tokens.delete_all
        ClientDeviceSession.where(id: token.device_session_id).delete_all

        assert_not ClientToken.exists?(id: token.id)
        assert_empty transactions
      else
        tokens = OperatorToken.where(id: token.id)
        transactions = OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id)
        transactions = transactions.where.not(id: existing_transaction_ids)
        OperatorStepUpSession.where(staff_token_id: tokens.select(:id)).delete_all
        OperatorAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transactions.select(:id)).delete_all
        OperatorAuthCeremonySession.where(
          step_up_ceremony_transaction_ref: transactions.select(:transaction_id),
        ).delete_all
        transactions.delete_all
        OpOrgGrant.where(operator_token_id: tokens.select(:id)).includes(:logout_hint).destroy_all
        OperatorDeviceSession.where(id: token.device_session_id).update_all(current_refresh_token_id: nil)
        tokens.delete_all
        OperatorDeviceSession.where(id: token.device_session_id).delete_all

        assert_not OperatorToken.exists?(id: token.id)
        assert_empty transactions
      end
    end
  end

  test "Base passkey rename and deletion require scoped step-up in app and org" do
    [[Client, ClientPasskey, ClientToken, OpAppGrant, :user_id, :client_token, "app", "client"],
     [Operator, OperatorPasskey, OperatorToken, OpOrgGrant, :staff_id, :operator_token,
      "org", "operator",],].each do |actor_class, key_class, token_class, rp_class, owner_key, root_key, surface, type|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      token = token_class.create!(
        :authentication_epoch => 0, owner_key => actor.id,
        :root_login_established_at => Time.current,
      )
      transaction_class = (surface == "app") ? ClientStepUpCeremonyTransaction : OperatorStepUpCeremonyTransaction
      @op_actors << [actor, token, transaction_class.where(actor_ref: actor.public_id).pluck(:id)]
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      # D-132: ADVANCED Operators keep two active Passkeys after the removal.
      ((key_class == OperatorPasskey) ? 2 : 1).times do
        key_class.create!(
          owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
          :public_key => "surviving-key", **metadata,
        )
      end
      target = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
        :public_key => "target-key", :description => "Original", **metadata,
      )
      client = OidcClientRegistry.find!("base-#{surface}-ww")
      host = URI.parse(client.redirect_uris.first).host
      rp = rp_class.create!(
        :authentication_epoch => 0,
        root_key => token, :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid,
        :oidc_auth_time => Time.current, :refresh_token_expires_at => 10.minutes.from_now,
      )
      access = AuthenticationTokenService.encode(
        actor, host: host, resource_type: type, session_public_id: token.public_id,
               base_session_public_id: token.public_id, oidc_sid: rp.public_id, oidc_jti: rp.oidc_jti,
               expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(client),
               audiences: [client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
               subject: OidcSubject.for(actor, resource_type: type), client_id: client.client_id,
      )
      browser = open_session
      browser.https!
      browser.host!(host)
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp.issue_refresh_token!
      ref = (key_class == OperatorPasskey) ? target.external_id : target.public_id
      path =
        case surface
        when "app" then base_app_identity_passkey_path(ref, ri: "jp")
        when "org" then base_org_identity_passkey_path(ref, ri: "jp")
        else raise ArgumentError, "unsupported test surface"
        end
      headers = { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://#{host}" }

      browser.get(path, headers: headers)

      assert_equal 302, browser.response.status, surface
      verification = URI.parse(browser.response.location)
      query = Rack::Utils.parse_query(verification.query)

      assert_equal "/verification", verification.path
      assert_equal "settings_passkey", query.fetch("scope")
      browser.get(verification.request_uri, headers: headers)

      assert_equal 200, browser.response.status, surface
      transaction_class = (surface == "app") ? ClientStepUpCeremonyTransaction : OperatorStepUpCeremonyTransaction
      before = transaction_class.where(actor_ref: actor.public_id).pluck(:id)
      browser.post(verification.path, params: { scope: "settings_passkey", pt: query.fetch("pt") }, headers: headers)

      assert_equal 303, browser.response.status, surface
      transaction = transaction_class.where(actor_ref: actor.public_id).where.not(id: before).sole

      assert_equal ref, transaction.resource_ref
      foreign_actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      foreign_key = key_class.create!(
        owner_key => foreign_actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "foreign-key", **metadata,
      )
      foreign_ref = (key_class == OperatorPasskey) ? foreign_key.external_id : foreign_key.public_id
      foreign_target = ActiveSupport::MessageVerifier.new(
        Rails.application.key_generator.generate_key("path_target_token", 32),
        digest: "SHA256", serializer: JSON, url_safe: true,
      ).generate(
        { "flow" => "step_up.bootstrap",
          "surface" => surface,
          "session_nonce" => token.public_id,
          "pt" => path.sub(ref, foreign_ref), },
        purpose: :path_target, expires_in: 15.minutes,
      )
      browser.get(
        "/verification", params: { scope: "settings_passkey", pt: foreign_target, ri: "jp" },
                         headers: headers,
      )

      assert_equal 400, browser.response.status, surface
      assert IdentityStepUpCeremonyCancellationCommitter.call!(actor: actor, token: token, transaction: transaction)
      browser.patch(path, params: { passkey: { description: "Changed" } }, headers: headers)

      assert_equal 401, browser.response.status, "#{surface}: #{browser.response.body.first(100)}"
      assert_equal "Original", target.reload.description
      browser.delete(path, headers: headers)

      assert_equal 401, browser.response.status, "#{surface}: #{browser.response.body.first(100)}"
      assert_equal 1, target.reload.status_id

      token.update!(
        last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
        last_step_up_credential_ref: ref, last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:#{surface}",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_full_reauthentication: false, last_step_up_resource_ref: ref,
      )
      [{ last_step_up_scope: "settings_email" }, { last_step_up_at: 16.minutes.ago }].each do |invalid|
        token.update!({ last_step_up_scope: "settings_passkey", last_step_up_at: Time.current }.merge(invalid))
        browser.patch(path, params: { passkey: { description: "Changed" } }, headers: headers)

        assert_equal 401, browser.response.status
        assert_equal "Original", target.reload.description
        browser.delete(path, headers: headers)

        assert_equal 401, browser.response.status
        assert_equal 1, target.reload.status_id
      end
      token.update!(
        last_step_up_scope: "settings_passkey", last_step_up_at: Time.current,
        last_step_up_resource_ref: nil,
      )

      assert_base_passkey_registration_options!(
        browser:, surface:, token:, headers:,
      )
      token.reload.update!(last_step_up_resource_ref: ref)
      failure = ->(**) { raise IdentityPasskeyNameCommitter::DependencyFailure, "injected storage failure" }
      IdentityPasskeyNameCommitter.stub(:call!, failure) do
        browser.patch(path, params: { passkey: { description: "Changed" } }, headers: headers)

        assert_equal 503, browser.response.status, surface
        assert_equal "Original", target.reload.description
        assert_predicate token.reload.last_step_up_at, :present?
      end
      op_record = (surface == "app") ? OpBaseAppRecord : OpBaseOrgRecord
      evidence_at = token.reload.last_step_up_at
      [false, true].each do |savepoint|
        op_record.transaction do
          op_record.transaction(requires_new: savepoint) do
            browser.patch(path, params: { passkey: { description: "Changed" } }, headers: headers)

            assert_equal 503, browser.response.status, "#{surface}, savepoint #{savepoint}"
            assert_equal "Original", target.reload.description
            assert_equal evidence_at, token.reload.last_step_up_at
          end
          raise ActiveRecord::Rollback
        end
      end
      browser.patch(path, params: { passkey: { description: "Changed" } }, headers: headers)

      assert_equal 303, browser.response.status, "#{surface}: #{browser.response.body.first(100)}"
      assert_equal "Changed", target.reload.description
      # adr/authentication-security-mode.md D3: the rename spent its Step-Up; deletion needs a new one.
      browser.delete(path, headers: headers)

      assert_equal 401, browser.response.status, "#{surface}: Step-Up evidence was reused"
      assert_equal 1, target.reload.status_id
      token.reload.update!(
        last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
        last_step_up_credential_ref: ref, last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:#{surface}",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_full_reauthentication: false, last_step_up_resource_ref: ref,
      )
      browser.delete(path, headers: headers)

      assert_equal 303, browser.response.status, "#{surface}: #{browser.response.body.first(100)}"
      assert_not target.class.exists?(target.id),
                 "#{surface}: passkey removal must physically delete the current credential"
    end
  end

  private

  def assert_base_passkey_registration_options!(browser:, surface:, token:, headers:)
    auth_host = auth_service_host(surface)
    reference = base_registration_handoff_reference(browser, surface, headers, auth_host)
    options = auth_registration_options(surface, token, auth_host, reference)
    expected_label = "umaxica.#{surface}"

    assert_equal [expected_label, expected_label], [options.dig("user", "name"), options.dig("user", "displayName")]
    assert_equal "required", options.dig("authenticatorSelection", "residentKey")
  ensure
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  def base_registration_handoff_reference(browser, surface, headers, auth_host)
    new_path = public_send("new_base_#{surface}_identity_passkey_path", ri: "jp")
    collection_path = public_send("base_#{surface}_identity_passkeys_path", ri: "jp")

    browser.get(new_path, headers: headers)

    assert_equal 200, browser.response.status, "#{surface}: #{browser.response.body.first(100)}"
    csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    browser.post(collection_path, params: { authenticity_token: csrf, ri: "jp" }, headers: headers)

    assert_equal 303, browser.response.status, "#{surface}: #{browser.response.body.first(100)}"
    registration_uri = URI.parse(browser.response.location)

    assert_equal auth_host, registration_uri.host
    Rack::Utils.parse_query(registration_uri.query).fetch("entry_ref")
  end

  def auth_registration_options(surface, token, auth_host, reference)
    binding = auth_admission_binding(surface, reference)

    assert_equal "credential_registration_handoff", binding.purpose

    auth_browser = open_session
    auth_browser.host!(auth_host)
    auth_browser.https!
    auth_registration_path = public_send("new_auth_#{surface}_verification_registration_passkey_path", ri: "jp")
    admit_auth_ceremony_entry!(
      auth_registration_path,
      reference:,
      params: { ri: "jp" },
      browser: auth_browser,
      base_token: token,
      browser_digest: binding.base_browser_digest,
    )
    auth_browser.get(auth_registration_path)

    assert_equal 200, auth_browser.response.status, "#{surface}: #{auth_browser.response.body.first(100)}"
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    options_path = public_send("auth_#{surface}_verification_registration_passkey_options_path", ri: "jp")
    auth_browser.post(options_path, params: { "cf-turnstile-response" => "test-only" }, as: :json)

    assert_equal 200, auth_browser.response.status, "#{surface}: #{auth_browser.response.body.first(100)}"

    auth_browser.response.parsed_body.fetch("options")
  end

  def auth_service_host(surface)
    {
      "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
    }.fetch(surface)
  end

  def auth_admission_binding(surface, reference)
    {
      "app" => ClientAuthAdmissionBinding,
      "org" => OperatorAuthAdmissionBinding,
    }.fetch(surface).find_by!(entry_ref: reference)
  end
end
