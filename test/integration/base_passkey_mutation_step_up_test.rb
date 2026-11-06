# frozen_string_literal: true

require "test_helper"

class BasePasskeyMutationStepUpTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  skip_transactional_tests_for_database :op_base_app
  skip_transactional_tests_for_database :op_base_org
  skip_transactional_tests_for_database :app_zenith
  skip_transactional_tests_for_database :org_zenith

  setup do
    @op_actors = []
    @rp_enrollments = []
    @zenith_actors = []
  end

  teardown do
    @rp_enrollments.each do |surface, enrollment|
      case surface
      when "app"
        RpBaseAppRecord.connected_to(role: :writing) do
          session = RpBaseAppSession.find(enrollment.session.id)
          binding = RpBaseAppOpSessionBinding.find(session.op_session_binding_id)
          identity = RpBaseAppIdentityBinding.find(binding.identity_binding_id)
          RpBaseAppSessionSelection.where(rp_session_id: session.id).delete_all
          RpStepUpState.where(rp_session_id: session.id).delete_all
          RpBaseAppEventReceipt.where(op_session_binding_id: binding.id).delete_all
          RpBaseAppSession.where(id: session.id).delete_all
          RpBaseAppOpSessionBinding.where(id: binding.id).delete_all
          RpBaseAppIdentityBinding.where(id: identity.id).delete_all
          RpBaseAppPrincipal.where(id: identity.principal_id).delete_all
        end
      when "org"
        RpBaseOrgRecord.connected_to(role: :writing) do
          session = RpBaseOrgSession.find(enrollment.session.id)
          binding = RpBaseOrgOpSessionBinding.find(session.op_session_binding_id)
          identity = RpBaseOrgIdentityBinding.find(binding.identity_binding_id)
          RpBaseOrgStepUpState.where(rp_session_id: session.id).delete_all
          RpBaseOrgEventReceipt.where(op_session_binding_id: binding.id).delete_all
          RpBaseOrgSession.where(id: session.id).delete_all
          RpBaseOrgOpSessionBinding.where(id: binding.id).delete_all
          RpBaseOrgIdentityBinding.where(id: identity.id).delete_all
          RpBaseOrgPrincipal.where(id: identity.principal_id).delete_all
        end
      else
        raise ArgumentError, "unsupported RP enrollment surface"
      end
    end

    @op_actors.each do |actor, token, existing_transaction_ids|
      if actor.is_a?(Client)
        tokens = ClientToken.where(id: token.id)
        transactions = ClientStepUpCeremonyTransaction.where(actor_ref: actor.public_id)
        transactions = transactions.where.not(id: existing_transaction_ids)
        admission_bindings = ClientAuthAdmissionBinding.where(base_token_id: tokens.select(:id))
          .or(ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transactions.select(:id)))
        auth_session_ids = admission_bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id)
          .flatten.compact.uniq
        ClientStepUpSession.where(user_token_id: tokens.select(:id)).delete_all
        ClientStepUpCommit.where(root_token_id: tokens.select(:id)).delete_all
        admission_bindings.delete_all
        ClientAuthCeremonySession.where(id: auth_session_ids).delete_all
        ClientAuthCeremonySession.where(
          step_up_ceremony_transaction_ref: transactions.select(:transaction_id),
        ).delete_all
        transactions.delete_all
        ClientOidcConnection.where(user_id: actor.id).delete_all
        app_grants = OpAppGrant.where(client_token_id: tokens.select(:id))
        OpAppGrantLogoutHint.where(grant_id: app_grants.select(:id)).delete_all
        app_grants.delete_all

        assert_not ClientOidcConnection.exists?(user_id: actor.id)
        assert_not OpAppGrant.exists?(client_token_id: token.id)
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
        OperatorStepUpCommit.where(root_token_id: tokens.select(:id)).delete_all
        OperatorAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transactions.select(:id)).delete_all
        OperatorAuthCeremonySession.where(
          step_up_ceremony_transaction_ref: transactions.select(:transaction_id),
        ).delete_all
        transactions.delete_all
        OperatorOidcConnection.where(staff_id: actor.id).delete_all
        org_grants = OpOrgGrant.where(operator_token_id: tokens.select(:id))
        OpOrgGrantLogoutHint.where(grant_id: org_grants.select(:id)).delete_all
        org_grants.delete_all

        assert_not OperatorOidcConnection.exists?(staff_id: actor.id)
        assert_not OpOrgGrant.exists?(operator_token_id: token.id)
        OperatorDeviceSession.where(id: token.device_session_id).update_all(current_refresh_token_id: nil)
        tokens.delete_all
        OperatorDeviceSession.where(id: token.device_session_id).delete_all

        assert_not OperatorToken.exists?(id: token.id)
        assert_empty transactions
      end
    end

    @zenith_actors.each do |actor|
      if actor.is_a?(Client)
        passkeys = ClientPasskey.where(user_id: actor.id)
        ClientPasskeyAuditOutbox.where(actor_ref: actor.public_id).delete_all
        passkeys.delete_all
        ClientPreference.where(client_id: actor.id).destroy_all
        Client.where(id: actor.id).delete_all
      else
        passkeys = OperatorPasskey.where(staff_id: actor.id)
        OperatorPasskeyAuditOutbox.where(actor_ref: actor.public_id).delete_all
        passkeys.delete_all
        OperatorPreference.where(operator_id: actor.id).destroy_all
        Operator.where(id: actor.id).delete_all
      end
    end
  end

  test "Base passkey rename and deletion reuse current OP evidence in app and org" do
    [
      [Client, ClientPasskey, ClientToken, OpAppGrant, ClientStepUpCommit, :user_id, :client_token, "app", "client"],
      [Operator, OperatorPasskey, OperatorToken, OpOrgGrant, OperatorStepUpCommit, :staff_id, :operator_token,
       "org", "operator",],
    ].each do |actor_class, key_class, token_class, grant_class, commit_class, owner_key, root_key, surface, type|
      actor_status_id = (actor_class == Client) ? ClientStatus::ACTIVE : OperatorStatus::ACTIVE
      actor = actor_class.create!(
        security_mode_id: SecurityModeTestDefault.id_for(actor_class),
        status_id: actor_status_id,
      )
      @zenith_actors << actor
      record_class = (surface == "app") ? OpBaseAppRecord : OpBaseOrgRecord
      now = record_class.database_now
      token_attributes = {
        :authentication_epoch => actor.authentication_epoch,
        owner_key => actor.id,
        :root_login_established_at => now,
        :discard_at => now + 1.hour,
      }
      if surface == "app"
        token_attributes[:user_token_kind_id] = ClientTokenKind::BROWSER_WEB
        token_attributes[:user_token_status_id] = ClientTokenStatus::ACTIVE
      else
        token_attributes[:staff_token_kind_id] = OperatorTokenKind::BROWSER_WEB
        token_attributes[:staff_token_status_id] = OperatorTokenStatus::ACTIVE
        token_attributes[:authentication_context] = AuthenticationContextValue::NORMAL_KEY
      end
      token = token_class.create!(token_attributes)
      actor_entry = [actor, token, []]
      @op_actors << actor_entry
      token.rotate_refresh_token!(now:)
      token.device_session_record!
      transaction_class = (surface == "app") ? ClientStepUpCeremonyTransaction : OperatorStepUpCeremonyTransaction
      actor_entry[2].concat(transaction_class.where(actor_ref: actor.public_id).pluck(:id))

      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: now }
      survivor_count = (key_class == OperatorPasskey) ? 2 : 1
      survivor_count.times do |index|
        key_class.create!(
          owner_key => actor.id,
          :webauthn_id => SecureRandom.uuid,
          :public_key => "surviving-key-#{index}",
          **metadata,
        )
      end
      target = key_class.create!(
        owner_key => actor.id,
        :webauthn_id => SecureRandom.uuid,
        :public_key => "target-key",
        :description => "Original",
        **metadata,
      )
      client = OidcClientRegistry.find!("base-#{surface}-ww")
      host = URI.parse(client.redirect_uris.first).host
      auth_time = now.to_i - 1
      grant = grant_class.create!(
        :authentication_epoch => token.authentication_epoch,
        root_key => token,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile",
        :oidc_jti => SecureRandom.uuid,
        :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => Time.at(auth_time).utc,
        :oidc_acr => StepUpEvidenceResolver::STEP_UP_ACR,
        :oidc_amr => JSON.generate(["passkey"]),
        :refresh_token_expires_at => now + 1.hour,
      )
      refresh_token = grant.issue_refresh_token!(now:)
      commit_class.create!(
        grant: grant,
        root_token: token,
        context_ref: PublicId.generate,
        verified_method: "passkey",
        committed_at: Time.at(auth_time).utc,
      )
      enrollment = RpCallbackCommitter.call(
        cell: RpCellBinding.for_client(client.client_id), issuer: OidcIssuer.for_client(client),
        subject: OidcSubject.for(actor, resource_type: type), sid: grant.public_id,
        absolute_expires_at: now + 1.hour,
      )

      assert_predicate enrollment, :success?
      @rp_enrollments << [surface, enrollment]
      access = AuthenticationTokenService.encode(
        actor,
        host: host,
        resource_type: type,
        session_public_id: token.public_id,
        base_session_public_id: token.public_id,
        oidc_sid: grant.public_id,
        oidc_jti: grant.oidc_jti,
        expires_at: now + 10.minutes,
        scopes: %w(openid profile),
        acr: StepUpEvidenceResolver::STEP_UP_ACR,
        amr: ["passkey"],
        auth_time: auth_time,
        authentication_context: AuthenticationContextValue::NORMAL_KEY,
        issuer: OidcIssuer.for_client(client),
        audiences: [client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
        subject: OidcSubject.for(actor, resource_type: type),
        client_id: client.client_id,
      )
      payload = AuthenticationTokenService.decode(
        access, host:, resource_type: type, issuer: OidcIssuer.for_client(client),
                audiences: [client.aud],
                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      )
      access_state = BrowserRpAuthentication::AccessState.new(
        status: :valid, resource: enrollment.principal, rp_session: enrollment.session, payload:,
        security_context: nil,
      )
      evidence = StepUpEvidenceResolver.call(access_state:, actor:, cell: RpCellBinding.for_client(client.client_id))

      assert_predicate evidence, :present?, "#{surface}: the exact access JWT event must resolve"
      browser = open_session
      browser.https!
      browser.host!(host)
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh_token
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
      ref = (key_class == OperatorPasskey) ? target.external_id : target.public_id
      path =
        case surface
        when "app" then base_app_identity_passkey_path(ref, ri: "jp")
        when "org" then base_org_identity_passkey_path(ref, ri: "jp")
        else raise ArgumentError, "unsupported test surface"
        end
      headers = { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://#{host}" }

      browser.get(path, headers: headers)

      assert_equal 200, browser.response.status, surface
      assert_equal access, browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE],
                   "#{surface}: display GET must retain the same access evidence"
      browser.patch(path, params: { passkey: { description: "Changed" } }, headers: headers)

      assert_equal 303, browser.response.status,
                   "#{surface}: #{browser.response.body}; auth=#{browser.response.headers["WWW-Authenticate"].inspect}"
      assert_equal "Changed", target.reload.description
      principal_record = (surface == "app") ? AppZenithRecord : OrgZenithRecord
      principal_connection = principal_record.lease_connection
      principal_commit = principal_connection.method(:commit_db_transaction)
      principal_commit_count = 0
      lose_removal_acknowledgement =
        lambda do
          principal_commit.call
          principal_commit_count += 1
          if principal_commit_count == 2
            principal_connection.disconnect!
            raise ActiveRecord::ConnectionNotEstablished, "injected lost passkey removal acknowledgement"
          end
        end
      principal_connection.stub(:commit_db_transaction, lose_removal_acknowledgement) do
        principal_connection.stub(:rollback_db_transaction, -> { }) do
          browser.delete(path, headers: headers)
        end
      end

      assert_equal 303, browser.response.status,
                   "#{surface}: the same current OP event must be reusable: #{browser.response.body}"
      assert_equal 2, principal_commit_count, "#{surface}: the final Zenith commit acknowledgement is lost"

      assert_not key_class.exists?(target.id), "#{surface}: passkey removal must physically delete the credential"
      passkey_outbox_class = (surface == "app") ? ClientPasskeyAuditOutbox : OperatorPasskeyAuditOutbox
      removed_event = passkey_outbox_class.find_by!(external_id: target.external_id, event_type: "passkey.removed")

      assert_predicate removed_event.operation_ref, :present?, "#{surface}: removal has a stable commit receipt"
      assert_predicate token.reload, :currently_usable?, "#{surface}: credential removal retains the current root"
      assert_nil grant.reload.revoked_at, "#{surface}: the current OP grant remains the evidence source"
    end
  end

  test "ORG Standby cannot start the Step-Up protected Email registration" do
    actor = Operator.create!(security_mode_id: SecurityModeTestDefault.id_for(Operator))
    @zenith_actors << actor
    2.times do
      OperatorPasskey.create!(
        staff_id: actor.id,
        webauthn_id: SecureRandom.urlsafe_base64(32),
        external_id: SecureRandom.uuid,
        public_key: "standby-email-test-public-key",
        sign_count: 0,
        description: "Standby Email test Passkey",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: actor.id,
      root_login_established_at: Time.current,
      established_authentication_method: "passkey",
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    token.rotate_refresh_token!(now: OperatorToken.database_now)
    token.device_session_record!
    existing_transactions = OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).pluck(:id)
    @op_actors << [actor, token, existing_transactions]
    BaseSelectorAuthority.prepare(surface: :org, principal: actor, session: token)

    client = OidcClientRegistry.find!("base-org-ww")
    host = URI.parse(client.redirect_uris.first).host
    rp_grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(client.client_id), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"), sid: rp_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    @rp_enrollments << ["org", enrollment]
    access_token = AuthenticationTokenService.encode(
      actor,
      host: host,
      resource_type: "operator",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: rp_grant.public_id,
      oidc_jti: rp_grant.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"),
      client_id: client.client_id,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    browser = open_session
    browser.https!
    browser.host!(host)
    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
    browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id

    headers = { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://#{host}" }
    assert_no_difference -> { OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count } do
      assert_no_difference -> { OperatorEmail.where(staff_id: actor.id).count } do
        browser.get(new_base_org_identity_emails_registration_path(ri: "jp"), headers: headers)

        assert_equal 403, browser.response.status, "Standby must not render the registration form"

        browser.post(
          base_org_identity_emails_registration_path(ri: "jp"),
          params: { staff_email: { raw_address: "standby_registration@example.com" } }, headers: headers,
        )

        assert_equal 403, browser.response.status, "Standby must not create a registration or issue an OTP"

        browser.get(edit_base_org_identity_emails_registration_path(ri: "jp"), headers: headers)

        assert_equal 403, browser.response.status, "Standby must not render the verification step"

        browser.patch(
          base_org_identity_emails_registration_path(ri: "jp"),
          params: { staff_email: { pass_code: "123456" } }, headers: headers,
        )

        assert_equal 403, browser.response.status, "Standby must not verify a registration code"
      end
    end
    assert_equal AuthenticationContextValue::STANDBY_KEY, token.reload.authentication_context
  end

  test "ORG Standby cannot bootstrap Secret enrollment" do
    actor = Operator.create!(security_mode_id: SecurityModeTestDefault.id_for(Operator))
    @zenith_actors << actor
    2.times do
      OperatorPasskey.create!(
        staff_id: actor.id,
        webauthn_id: SecureRandom.urlsafe_base64(32),
        external_id: SecureRandom.uuid,
        public_key: "standby-secret-enrollment-test-public-key",
        sign_count: 0,
        description: "Standby Secret enrollment test Passkey",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: actor.id,
      root_login_established_at: Time.current,
      established_authentication_method: "passkey",
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    token.rotate_refresh_token!(now: OperatorToken.database_now)
    token.device_session_record!
    existing_transactions = OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).pluck(:id)
    @op_actors << [actor, token, existing_transactions]
    BaseSelectorAuthority.prepare(surface: :org, principal: actor, session: token)

    client = OidcClientRegistry.find!("base-org-ww")
    host = URI.parse(client.redirect_uris.first).host
    rp_grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(client.client_id), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"), sid: rp_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    @rp_enrollments << ["org", enrollment]
    access_token = AuthenticationTokenService.encode(
      actor,
      host: host,
      resource_type: "operator",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: rp_grant.public_id,
      oidc_jti: rp_grant.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"),
      client_id: client.client_id,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    browser = open_session
    browser.https!
    browser.host!(host)
    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
    browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    headers = { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://#{host}" }

    assert_no_difference -> { OperatorSecretCredential.count } do
      assert_no_difference -> { OperatorSecretCredentialCeremonyTransaction.count } do
        assert_no_difference -> { OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count } do
          browser.get(new_base_org_identity_secret_path(ri: "jp"), headers: headers)

          assert_equal 503, browser.response.status, "the RP-local Secret feature remains explicitly unavailable"

          browser.post(
            base_org_identity_secrets_path(ri: "jp"),
            params: { secret_credential: { name: "standby-secret", enabled: "1" } }, headers: headers,
          )

          assert_equal 503, browser.response.status, "RP-local Secret create remains unavailable before authorization"
        end
      end
    end
    assert_equal AuthenticationContextValue::STANDBY_KEY, token.reload.authentication_context
  end

  test "ORG Standby cannot start the Step-Up protected Telephone registration" do
    actor = Operator.create!(security_mode_id: SecurityModeTestDefault.id_for(Operator))
    @zenith_actors << actor
    2.times do
      OperatorPasskey.create!(
        staff_id: actor.id,
        webauthn_id: SecureRandom.urlsafe_base64(32),
        external_id: SecureRandom.uuid,
        public_key: "standby-telephone-test-public-key",
        sign_count: 0,
        description: "Standby Telephone test Passkey",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: actor.id,
      root_login_established_at: Time.current,
      established_authentication_method: "passkey",
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    token.rotate_refresh_token!(now: OperatorToken.database_now)
    token.device_session_record!
    existing_transactions = OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).pluck(:id)
    @op_actors << [actor, token, existing_transactions]
    BaseSelectorAuthority.prepare(surface: :org, principal: actor, session: token)

    client = OidcClientRegistry.find!("base-org-ww")
    host = URI.parse(client.redirect_uris.first).host
    rp_grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(client.client_id), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"), sid: rp_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    @rp_enrollments << ["org", enrollment]
    access_token = AuthenticationTokenService.encode(
      actor,
      host: host,
      resource_type: "operator",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: rp_grant.public_id,
      oidc_jti: rp_grant.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"),
      client_id: client.client_id,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    browser = open_session
    browser.https!
    browser.host!(host)
    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
    browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id

    headers = { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://#{host}" }
    telephone_transactions = OperatorTelephoneCeremonyTransaction.where(actor_ref: actor.public_id)
    assert_no_difference -> { OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count } do
      assert_no_difference -> { OperatorTelephone.where(staff_id: actor.id).count } do
        assert_no_difference -> { telephone_transactions.count } do
          browser.get(new_base_org_identity_telephones_registration_path(ri: "jp"), headers: headers)

          assert_equal 403, browser.response.status, "Standby must not render the registration form"

          browser.post(
            base_org_identity_telephones_registration_path(ri: "jp"),
            params: { staff_telephone: { raw_number: "+12025550123" } }, headers: headers,
          )

          assert_equal 503, browser.response.status,
                       "RP-local contact registration remains unavailable before OTP issue"
        end
      end
    end
    assert_equal AuthenticationContextValue::STANDBY_KEY, token.reload.authentication_context
  end

  test "ORG Standby cannot revoke every other Operator session" do
    actor = Operator.create!(security_mode_id: SecurityModeTestDefault.id_for(Operator))
    @zenith_actors << actor
    2.times do
      OperatorPasskey.create!(
        staff_id: actor.id,
        webauthn_id: SecureRandom.urlsafe_base64(32),
        external_id: SecureRandom.uuid,
        public_key: "standby-session-revocation-test-public-key",
        sign_count: 0,
        description: "Standby session revocation test Passkey",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: actor.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      root_login_established_at: Time.current,
      established_authentication_method: "passkey",
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    token.rotate_refresh_token!(now: OperatorToken.database_now)
    token.device_session_record!
    existing_transactions = OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).pluck(:id)
    @op_actors << [actor, token, existing_transactions]
    BaseSelectorAuthority.prepare(surface: :org, principal: actor, session: token)
    other_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: actor.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    client = OidcClientRegistry.find!("base-org-ww")
    host = URI.parse(client.redirect_uris.first).host
    rp_grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(client.client_id), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"), sid: rp_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    @rp_enrollments << ["org", enrollment]
    access_token = AuthenticationTokenService.encode(
      actor,
      host: host,
      resource_type: "operator",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: rp_grant.public_id,
      oidc_jti: rp_grant.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"),
      client_id: client.client_id,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    browser = open_session
    browser.https!
    browser.host!(host)
    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
    browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    transactions_before = OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count

    browser.delete(
      base_org_identity_other_sessions_path(ri: "jp"),
      headers: { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://#{host}" },
    )

    assert_equal 503, browser.response.status
    assert_predicate other_token.reload, :currently_usable?
    assert_equal AuthenticationContextValue::STANDBY_KEY, token.reload.authentication_context
    assert_equal transactions_before, OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count
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

  def assert_org_standby_passkey_mutation_refused!(actor:, key_class:, owner_key:, root_key:, rp_class:, client:,
                                                   host:, type:)
    standby_token = create_org_standby_token(actor)
    standby_target = create_org_standby_passkey(actor, key_class, owner_key)
    standby_ref = standby_target.external_id
    standby_token.update!(standby_passkey_freshness_attributes(standby_token, standby_ref))
    freshness_at = standby_token.reload.last_step_up_at
    standby_browser = org_standby_browser(actor:, token: standby_token, root_key:, rp_class:, client:, host:, type:)
    transactions_before = OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count

    standby_browser.get(
      base_org_identity_passkey_path(standby_ref, ri: "jp"),
      headers: { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://#{host}" },
    )

    assert_standby_passkey_refused!(
      browser: standby_browser, target: standby_target, token: standby_token, actor:,
      freshness_at:, transactions_before:, action: "Passkey details page",
    )

    standby_browser.patch(
      base_org_identity_passkey_path(standby_ref, ri: "jp"),
      params: { passkey: { description: "Standby changed" } },
      headers: { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://#{host}" },
    )

    assert_standby_passkey_refused!(
      browser: standby_browser, target: standby_target, token: standby_token, actor:,
      freshness_at:, transactions_before:, action: "Passkey mutation",
    )

    standby_browser.delete(
      base_org_identity_passkey_path(standby_ref, ri: "jp"),
      headers: { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://#{host}" },
    )

    assert_standby_passkey_refused!(
      browser: standby_browser, target: standby_target, token: standby_token, actor:,
      freshness_at:, transactions_before:, action: "Passkey removal",
    )
    assert_equal 1, standby_target.reload.status_id
  end

  def assert_standby_passkey_refused!(browser:, target:, token:, actor:, freshness_at:, transactions_before:, action:)
    assert_equal 403, browser.response.status, "standby context must refuse the #{action}"
    assert_equal "Standby original", target.reload.description
    assert_equal freshness_at, token.reload.last_step_up_at
    assert_equal AuthenticationContextValue::STANDBY_KEY, token.authentication_context
    assert_equal transactions_before, OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count
  end

  def create_org_standby_token(actor)
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: actor.id,
      root_login_established_at: Time.current,
      established_authentication_method: "passkey",
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    existing_transactions = OperatorStepUpCeremonyTransaction.where(actor_ref: actor.public_id).pluck(:id)
    @op_actors << [actor, token, existing_transactions]
    BaseSelectorAuthority.prepare(surface: :org, principal: actor, session: token)
    token
  end

  def create_org_standby_passkey(actor, key_class, owner_key)
    attributes = { owner_key => actor.id }
    attributes.merge!(
      webauthn_id: SecureRandom.uuid,
      public_key: "standby-target-key",
      description: "Standby original",
    )
    key_class.create!(attributes)
  end

  def standby_passkey_freshness_attributes(token, reference)
    {
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_passkey",
      last_step_up_method: "passkey",
      last_step_up_credential_ref: reference,
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
      last_step_up_resource_ref: reference,
    }
  end

  def org_standby_browser(actor:, token:, root_key:, rp_class:, client:, host:, type:)
    grant_attributes = { root_key => token }
    grant_attributes.merge!(
      authentication_epoch: 0,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    grant = rp_class.create!(grant_attributes)
    access_token = AuthenticationTokenService.encode(
      actor,
      host: host,
      resource_type: type,
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: grant.public_id,
      oidc_jti: grant.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(actor, resource_type: type),
      client_id: client.client_id,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    browser = open_session
    browser.https!
    browser.host!(host)
    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = grant.issue_refresh_token!
    browser
  end
end
