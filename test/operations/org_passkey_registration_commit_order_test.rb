# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class OrgPasskeyRegistrationCommitOrderTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  fixtures :operator_statuses, :operator_security_modes, :operator_passkey_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  setup do
    @actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    @existing_passkeys =
      2.times.map do
        @actor.staff_passkeys.create!(
          webauthn_id: SecureRandom.uuid, public_key: SecureRandom.hex(32), uv_verified_at: Time.current,
        )
      end
    @token = OperatorToken.create!(
      authentication_epoch: 0, staff: @actor, root_login_established_at: Time.current,
    )
    now = OperatorToken.database_now
    @root_authentication_state = @token.attributes.slice(:root_login_established_at, :established_authentication_method)
    @token.rotate_refresh_token!(now:)
    @token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    @grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    @grant.issue_refresh_token!(now:)
    @step_up_evidence = StepUpEvidenceValue.new(
      acr: @grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: @grant.public_id,
      sub: OidcSubject.for(@actor, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: @grant.oidc_jti,
    )
    @requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "credential_registration", step_up_required: false,
      allowed_methods: [:passkey], phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: @actor.public_id,
      resource_ref: nil, tenant_ref: nil, audience: "step_up:org", session_binding: @token.public_id,
      token_binding: @token.public_id, require_session_binding: true,
    )
    @transaction = BaseStepUpAdmissionIssuer.call!(
      actor: @actor, token: @token, requirement: @requirement, return_to: "/identity/passkeys",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: @token, step_up_evidence: @step_up_evidence,
    ).transaction
    @record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: @transaction.transaction_id)
    @ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "credential_registration_handoff",
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )
    @fake = WebAuthn::FakeClient.new("https://auth.umaxica.org", encoding: :base64url)
    @config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: @fake.origin)
    @challenge = SecureRandom.urlsafe_base64(32)
    @reference = @record.issue_bound_passkey_registration_challenge!(
      transaction: @transaction, challenge: @challenge, rp_id: @config.rp_id, origin: @config.origin,
    )
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference,
      credential_params: @fake.create(
        challenge: @challenge, user_verified: true, extensions: { "credProps" => { "rk" => true } },
      ),
      description: "New org passkey",
    )
    @result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction.reload, ceremony_session_ref: @ceremony.id.to_s,
    )
  end

  teardown do
    ActiveRecord::Base.connection_handler.clear_active_connections!
    if @transaction
      OperatorAuthAdmissionBinding.where(step_up_ceremony_transaction_id: @transaction.id).delete_all
      OperatorAuthCeremonySession.where(step_up_ceremony_transaction_ref: @transaction.transaction_id).delete_all
      OperatorPasskeyCeremonyCandidate.where(
        step_up_ceremony_transaction_ref: @transaction.transaction_id,
      ).delete_all
      OperatorStepUpSession.where(step_up_ceremony_transaction_ref: @transaction.transaction_id).delete_all
      OperatorStepUpCeremonyTransaction.where(id: @transaction.id).delete_all
      OperatorPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).delete_all
    end
    if @actor
      OperatorPasskey.where(staff_id: @actor.id).delete_all
      if @token
        device_session_id = @token.device_session_id
        OpOrgGrant.where(operator_token_id: @token.id).delete_all
        OperatorToken.where(id: @token.id).delete_all
        OperatorDeviceSession.where(id: device_session_id).delete_all
      end
    end
  end

  test "an ORG OP commit failure preserves the verified evidence and registration candidate" do
    op_connection = OpBaseOrgRecord.lease_connection
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected ORG OP commit failure" }

    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      op_connection.stub(:commit_db_transaction, failed_commit) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
          step_up_evidence: @step_up_evidence,
        )
      end
    end

    candidate = OperatorPasskeyCeremonyCandidate.find_by!(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )

    assert_equal "verified", @transaction.reload.status
    assert_nil candidate.consumed_at
    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
    assert_not_predicate @ceremony.reload, :completed?
    assert_equal 2, @actor.reload.staff_passkeys.count
    assert_equal 0, OperatorPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).count
  end

  test "an ORG Zenith commit failure leaves registration committed in OP without a credential" do
    org_connection = Operator.lease_connection
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected ORG Zenith commit failure" }

    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      org_connection.stub(:commit_db_transaction, failed_commit) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
          step_up_evidence: @step_up_evidence,
        )
      end
    end

    candidate = OperatorPasskeyCeremonyCandidate.find_by!(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )

    assert_equal "consumed", @transaction.reload.status
    assert_not_nil candidate.consumed_at
    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
    assert_predicate @ceremony.reload, :completed?
    assert_equal 2, @actor.reload.staff_passkeys.count
    assert_equal 0, OperatorPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).count

    assert_raises(IdentityPasskeyCeremonyContract::Error) do
      IdentityPasskeyRegistrationFinalCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
        step_up_evidence: @step_up_evidence,
      )
    end
    assert_equal 2, @actor.reload.staff_passkeys.count
  end

  test "a lost ORG OP commit acknowledgement leaves registration committed without a Zenith credential" do
    op_connection = OpBaseOrgRecord.lease_connection
    commit = op_connection.method(:commit_db_transaction)
    lose_acknowledgement =
      lambda do
        commit.call
        op_connection.disconnect!
        raise PG::ConnectionBad, "injected ORG OP commit acknowledgement loss"
      end

    assert_raises(PG::ConnectionBad) do
      op_connection.stub(:commit_db_transaction, lose_acknowledgement) do
        op_connection.stub(:rollback_db_transaction, -> { }) do
          IdentityPasskeyRegistrationFinalCommitter.call!(
            actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
            step_up_evidence: @step_up_evidence,
          )
        end
      end
    end

    candidate = OperatorPasskeyCeremonyCandidate.find_by!(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )

    assert_equal "consumed", @transaction.reload.status
    assert_not_nil candidate.consumed_at
    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
    assert_predicate @ceremony.reload, :completed?
    assert_equal 2, @actor.reload.staff_passkeys.count
    assert_equal 0, OperatorPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).count
  end

  test "a lost ORG Zenith commit acknowledgement converges to the committed credential on retry" do
    org_connection = Operator.lease_connection
    commit = org_connection.method(:commit_db_transaction)
    lose_acknowledgement =
      lambda do
        commit.call
        org_connection.disconnect!
        raise PG::ConnectionBad, "injected ORG Zenith commit acknowledgement loss"
      end

    assert_raises(PG::ConnectionBad) do
      org_connection.stub(:commit_db_transaction, lose_acknowledgement) do
        org_connection.stub(:rollback_db_transaction, -> { }) do
          IdentityPasskeyRegistrationFinalCommitter.call!(
            actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
            step_up_evidence: @step_up_evidence,
          )
        end
      end
    end

    assert_equal "consumed", @transaction.reload.status
    candidate = OperatorPasskeyCeremonyCandidate.find_by!(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )
    first = @actor.reload.staff_passkeys.find_by!(webauthn_id: candidate.webauthn_id)

    assert_equal 1, OperatorPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).count
    retry_result = IdentityPasskeyRegistrationFinalCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
      step_up_evidence: @step_up_evidence,
    )

    assert_equal first.id, retry_result.id
    assert_equal 3, @actor.reload.staff_passkeys.count
    assert_equal 1, OperatorPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).count
  end
end
