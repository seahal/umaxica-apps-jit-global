# frozen_string_literal: true

require "test_helper"

class BaseStepUpAdmissionIssuerTest < ActiveSupport::TestCase
  test "APP and ORG refuse direct step-up admissions without an OP authorization context" do
    %w(app org).each do |surface|
      actor, token, transaction_model, session_model =
        case surface
        when "app"
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor),
           ClientStepUpCeremonyTransaction, ClientStepUpSession,]
        when "org"
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor),
           OperatorStepUpCeremonyTransaction, OperatorStepUpSession,]
        end
      requirement = StepUpRequirement.new(
        scope: OidcAuthorizeRequestResolver::STEP_UP_SCOPE, purpose: "step_up", step_up_required: true,
        allowed_methods: [:passkey], phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, audience: "step_up:#{surface}", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true, ttl: 5.minutes,
        actor_ref: actor.public_id, resource_ref: SecureRandom.hex(16), tenant_ref: nil,
      )
      error = nil

      assert_no_difference [-> { transaction_model.count }, -> { session_model.count }] do
        error =
          assert_raises(BaseAuthAdmissionCoordinator::Denied) do
            BaseStepUpAdmissionIssuer.call!(
              actor:, token:, requirement:, return_to: OidcAuthorizeRequestResolver::STEP_UP_RETURN_TO,
              base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: token,
            )
          end
      end

      assert_equal "malformed_request", error.code
      assert_nil token.reload.last_step_up_at
    end
  end

  test "regular registration requires current OP evidence and produces registration-only authority on each surface" do
    %i(app org).each do |surface|
      actor, token, parents =
        case surface
        when :app
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_112_000_000_000)
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor), ClientStepUpCeremonyTransaction]
        when :org
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 9_112_000_000_000)
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor), OperatorStepUpCeremonyTransaction]
        end
      requirement = StepUpRequirement.new(
        step_up_required: false, scope: "settings_passkey", allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes,
        purpose: "credential_registration", audience: "step_up:#{surface}",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      assert_no_difference(-> { parents.count }) do
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement,
            return_to: "/identity/passkeys",
            base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
          )
        end
      end
      record_class = (surface == :app) ? OpBaseAppRecord : OpBaseOrgRecord
      grant_class = (surface == :app) ? OpAppGrant : OpOrgGrant
      grant_token_key = (surface == :app) ? :client_token : :operator_token
      resource_type = (surface == :app) ? "client" : "operator"
      oidc_client = OidcClientRegistry.find!((surface == :app) ? "base-app-ww" : "base-org-ww")
      now = record_class.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      grant = grant_class.create!(
        **{ grant_token_key => token },
        authentication_epoch: token.authentication_epoch,
        oidc_client_id: oidc_client.client_id,
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: Time.at(now.to_i).utc,
        oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
        oidc_amr: JSON.generate(["passkey"]),
        refresh_token_expires_at: now + 1.hour,
      )
      grant.issue_refresh_token!(now:)
      event = now.to_i
      evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: event, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type: resource_type), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
      [
        { acr: "urn:invalid:acr" }, { amr: ["totp"] }, { sid: SecureRandom.uuid },
        { sub: "foreign-subject" }, { client_id: "foreign-client" }, { aud: ["urn:foreign"] },
        { jti: SecureRandom.uuid },
      ].each do |invalid_claims|
        invalid_evidence = StepUpEvidenceValue.new(**evidence.to_h.merge(invalid_claims))
        assert_no_difference(-> { parents.count }) do
          assert_raises(BaseAuthAdmissionCoordinator::Denied) do
            BaseStepUpAdmissionIssuer.call!(
              actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
              base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
              step_up_evidence: invalid_evidence,
            )
          end
        end
      end
      evidence_expires_at = event + StepUpEvidenceValue::MAX_AGE_SECONDS
      [0, 1].each do |microseconds|
        record_class.stub(:database_now, Time.zone.at(evidence_expires_at) + Rational(microseconds, 1_000_000)) do
          assert_no_difference(-> { parents.count }) do
            assert_raises(BaseAuthAdmissionCoordinator::Denied) do
              BaseStepUpAdmissionIssuer.call!(
                actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
                base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
                step_up_evidence: evidence,
              )
            end
          end
        end
      end
      issuance =
        record_class.stub(:database_now, Time.zone.at(evidence_expires_at) - Rational(1, 1_000_000)) do
          BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
            base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
            step_up_evidence: evidence,
          )
        end

      assert_equal "credential_registration", issuance.transaction.purpose
      assert_equal "none", issuance.transaction.required_aal
      assert_not issuance.transaction.phishing_resistant_required
      assert_nil token.reload.last_step_up_at
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: surface.to_s,
        reference: issuance.reference,
      )
      _auth_session, raw_sid =
        begin
          fv5019 = binding
          fv5018 = token
          fv5016, fv5015 = fv5019.class.auth_admission_session_class.issue!
          fv5019.attach_auth_session!(
            auth_session: fv5016, confirmation_ref: SecureRandom.uuid,
          )
          fv5017 = AuthAdmissionBinding.browser_digest(
            surface: fv5019.class.auth_admission_surface_name,
            entry_ref: fv5019.entry_ref,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          )
          fv5019.confirm_base!(
            base_token: fv5018,
            browser_digest: fv5017,
          )
          [fv5016, fv5015]
        end

      assert_equal issuance.transaction.transaction_id, BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: surface.to_s, expected_intent: "credential_registration",
        binding: binding, raw_auth_sid: raw_sid,
      ).fetch("subject_ref")
    end
  end

  test "APP TOTP registration accepts prior Email proof but rejects unrelated scopes and assurance claims" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_113_000_000_000)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["email_otp"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["email_otp"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    original_root_state = token.reload.attributes
    attributes = {
      step_up_required: false,
      scope: "settings_totp",
      allowed_methods: [:totp],
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      ttl: 15.minutes,
      purpose: "credential_registration",
      audience: "step_up:app",
      session_binding: token.public_id,
      token_binding: token.public_id,
      require_session_binding: true,
      actor_ref: actor.public_id,
      resource_ref: nil,
      tenant_ref: nil,
    }

    [
      { allowed_methods: [] }, { allowed_methods: [:passkey] }, { allowed_methods: [:email_otp] },
      { step_up_required: true },
      { scope: "settings_birthdate" }, { purpose: "credential_change" },
    ].each do |invalid|
      if invalid[:allowed_methods] == []
        assert_raises(ArgumentError) {
          StepUpRequirement.new(
            step_up_required: true,
            phishing_resistant_required: false,
            user_verification_required: false,
            full_reauthentication_required: false,
            **attributes.merge(invalid),
          )
        }
        next
      end

      requirement =
        begin
          StepUpRequirement.new(
            step_up_required: true,
            phishing_resistant_required: false,
            user_verification_required: false,
            full_reauthentication_required: false,
            **attributes.merge(invalid),
          )
        rescue ArgumentError
          next
        end

      assert_no_difference("ClientStepUpCeremonyTransaction.count") do
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement,
            return_to: "/identity/totps",
            base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
          )
        end
      end
    end
    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        step_up_required: true,
        phishing_resistant_required: false,
        user_verification_required: false,
        full_reauthentication_required: false,
        **attributes.merge(required_aal: :aal1),
      )
    end
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: StepUpRequirement.new(
        step_up_required: true,
        phishing_resistant_required: false,
        user_verification_required: false,
        full_reauthentication_required: false,
        **attributes,
      ), return_to: "/identity/totps",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
      step_up_evidence: evidence,
    )

    assert_equal ["totp"], issuance.transaction.allowed_methods_array
    assert_equal "credential_registration", issuance.transaction.purpose
    assert_equal original_root_state, token.reload.attributes
  end

  private
end
