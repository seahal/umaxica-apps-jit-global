# frozen_string_literal: true

require "test_helper"

class AppSecretStepUpBindingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  fixtures :clients, :client_statuses

  test "Secret root sessions cannot bootstrap a newly registered Step-Up method" do
    [[:passkey, "settings_passkey", "/settings/passkeys/new"],
     [:totp, "settings_totp", "/settings/totps/new"],].each do |method, scope, path|
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(authentication_epoch: 0, user: actor, established_authentication_method: "secret")
      requirement = StepUpRequirement.new(
        scope: scope, purpose: "bootstrap", step_up_required: false, allowed_methods: [method],
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, phishing_resistant_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )

      assert_no_difference("ClientStepUpCeremonyTransaction.count") do
        assert_no_difference("ClientStepUpSession.count") do
          assert_raises(BaseAuthAdmissionCoordinator::Denied) do
            BaseStepUpAdmissionIssuer.call!(
              actor: actor, token: token, requirement: requirement, return_to: path,
              base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
            )
          end
        end
      end
      assert_nil token.reload.last_step_up_at
      assert_equal "secret", token.established_authentication_method
    end
  end

  test "Secret management uses the OP step-up context without an AAL threshold" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
    token = ClientToken.create!(authentication_epoch: 0, user: actor, established_authentication_method: "secret")
    client = OidcClientRegistry.find!("base-app-ww")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    rp_enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(client.client_id), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(actor, resource_type: "client"), sid: grant.public_id,
      absolute_expires_at: now + 1.hour,
    )
    raise ArgumentError, "APP RP session setup failed: #{rp_enrollment.outcome}" unless rp_enrollment.success?

    verifier = SecureRandom.urlsafe_base64(32)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    ticket = issuance.ticket.reload

    assert_equal :issued, issuance.outcome
    assert_equal grant.public_id, rp_enrollment.session.op_session_binding.sid
    assert_nil rp_enrollment.session.revoked_at
    assert_equal OidcAuthorizeRequestResolver::STEP_UP_ACR, issuance.context.requested_acr
    assert_equal OidcAuthorizeRequestResolver::STEP_UP_SCOPE, ticket.required_scope
    assert_equal "step_up", ticket.purpose
    assert_equal actor.public_id, ticket.actor_ref
    assert_equal token.public_id, ticket.session_ref
    assert_equal issuance.context.public_id, ticket.resource_ref
    assert_equal ["passkey"], ticket.allowed_methods_array
    assert_equal "none", ticket.required_aal
    assert_not ticket.phishing_resistant_required
    assert_not ticket.user_verification_required
    assert_not ticket.full_reauthentication_required
    assert_equal "secret", token.reload.established_authentication_method
    assert_nil token.last_step_up_at
  end

  test "Secret management refuses the retired RP-local operation scope without an OP context" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, established_authentication_method: "secret")
    requirement = StepUpRequirement.new(
      scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:app",
      step_up_required: true,
      allowed_methods: %i(passkey totp), session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, phishing_resistant_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )

    assert_no_difference [-> { ClientStepUpCeremonyTransaction.count }, -> { ClientStepUpSession.count }] do
      error =
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseStepUpAdmissionIssuer.call!(
            actor:, token:, requirement:, return_to: "/secrets/new?ri=jp",
            base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
          )
        end
      assert_equal "malformed_request", error.code
    end

    assert_not requirement.method_allowed?(:secret)
    assert_equal "secret", token.reload.established_authentication_method
    assert_nil token.last_step_up_at
  end

  test "Secret management refuses bootstrap even before any authenticator is configured" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    requirement = StepUpRequirement.new(
      step_up_required: false, scope: "settings_secret_credential", purpose: "bootstrap",
      audience: "step_up:app", allowed_methods: [:passkey],
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
      actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseStepUpAdmissionIssuer.call!(
        actor: actor, token: token, requirement: requirement, return_to: "/secrets/new",
        base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
      )
    end
  end

  test "Secret scope cannot authorize another operation legacy path or arbitrary destination" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    requirement = StepUpRequirement.new(
      scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:app",
      step_up_required: true,
      allowed_methods: [:passkey], session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, phishing_resistant_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )

    ["/settings/secrets", "/settings/secret_credentials", "/secrets-extra", "/identity/emails",
     "https://untrusted.example/secrets", "//untrusted.example/secrets",].each do |path|
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
          actor: actor, token: token, requirement: requirement, return_to: path,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
        )
      end
    end
  end

  test "Secret management refuses another session binding without a transaction" do
    actor = clients(:one)
    first = ClientToken.create!(authentication_epoch: 0, user: actor)
    second = ClientToken.create!(authentication_epoch: 0, user: actor)
    requirement = StepUpRequirement.new(
      scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:app",
      step_up_required: true,
      allowed_methods: [:passkey], session_binding: first.public_id,
      token_binding: first.public_id, require_session_binding: true, phishing_resistant_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )

    assert_no_difference("ClientStepUpCeremonyTransaction.count") do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
          actor: actor,
          token: second,
          requirement: requirement,
          return_to: "/secrets/new",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: second,
        )
      end
    end
  end

  test "Secret itself cannot be the method of Secret management Step-Up" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, established_authentication_method: "secret")
    requirement = StepUpRequirement.new(
      scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:app",
      step_up_required: true,
      allowed_methods: [:secret_credential], session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, phishing_resistant_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )

    assert_no_difference("ClientStepUpCeremonyTransaction.count") do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
          actor: actor,
          token: token,
          requirement: requirement,
          return_to: "/secrets/new",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: token,
        )
      end
    end
  end

  test "ORG Secret management is admitted through its OP step-up context" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    client = OidcClientRegistry.find!("base-org-ww")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    rp_enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(client.client_id), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"), sid: grant.public_id,
      absolute_expires_at: now + 1.hour,
    )
    raise ArgumentError, "ORG RP session setup failed: #{rp_enrollment.outcome}" unless rp_enrollment.success?

    verifier = SecureRandom.urlsafe_base64(32)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "operator")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor:, token:, client:, params:, validated_request:,
    )
    ticket = issuance.ticket.reload

    assert_equal :issued, issuance.outcome
    assert_equal grant.public_id, rp_enrollment.session.op_session_binding.sid
    assert_nil rp_enrollment.session.revoked_at
    assert_equal OidcAuthorizeRequestResolver::STEP_UP_ACR, issuance.context.requested_acr
    assert_equal OidcAuthorizeRequestResolver::STEP_UP_SCOPE, ticket.required_scope
    assert_equal "step_up", ticket.purpose
    assert_equal actor.public_id, ticket.actor_ref
    assert_equal token.public_id, ticket.session_ref
    assert_equal issuance.context.public_id, ticket.resource_ref
    assert_equal ["passkey"], ticket.allowed_methods_array
    assert_equal "none", ticket.required_aal
    assert_not ticket.phishing_resistant_required
    assert_not ticket.user_verification_required
    assert_not ticket.full_reauthentication_required
  end

  test "ORG refuses the retired Secret management scope without an OP context" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    requirement = StepUpRequirement.new(
      scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:org",
      step_up_required: true, allowed_methods: [:passkey], session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, phishing_resistant_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )

    assert_no_difference [-> { OperatorStepUpCeremonyTransaction.count }, -> { OperatorStepUpSession.count }] do
      error =
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseStepUpAdmissionIssuer.call!(
            actor:, token:, requirement:, return_to: "/identity/secrets",
            base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
          )
        end
      assert_equal "malformed_request", error.code
    end
  end
end
