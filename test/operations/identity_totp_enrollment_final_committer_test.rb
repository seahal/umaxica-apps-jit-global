# frozen_string_literal: true

require "test_helper"

class IdentityTotpEnrollmentFinalCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  setup do
    @test_actors = []
  end

  teardown do
    token_ids = ClientToken.where(user_id: @test_actors.map(&:id)).select(:id)
    OpAppGrant.where(client_token_id: token_ids).delete_all
    @test_actors.each do |actor|
      ClientTotpCredential.where(user_id: actor.id).delete_all
      step_up_transactions = ClientStepUpCeremonyTransaction.where(actor_ref: actor.public_id)
      transaction_ids = step_up_transactions.pluck(:id)
      transaction_refs = step_up_transactions.pluck(:transaction_id)

      ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transaction_ids).delete_all
      ClientStepUpSession.where(step_up_ceremony_transaction_ref: transaction_refs).delete_all
      ClientTotpCeremonyTransaction.where(step_up_ceremony_transaction_ref: transaction_refs).delete_all
      IdentityTotpCeremonyCandidate.where(step_up_ceremony_transaction_ref: transaction_refs).delete_all
      ClientAuthCeremonySession.where(step_up_ceremony_transaction_ref: transaction_refs).delete_all
      step_up_transactions.delete_all

      ClientDeviceSession.where(user_id: actor.id).update_all(current_refresh_token_id: nil)
      ClientToken.where(user_id: actor.id).delete_all
      ClientDeviceSession.where(user_id: actor.id).delete_all
      ClientAuthorityLock.where(client_id: actor.id).delete_all
      actor.delete
    end
  end

  test "a revoked device cannot finalize a verified TOTP enrollment" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @test_actors << actor
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "bootstrap",
      required_scope: "settings_totp", required_aal: "none", step_up_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
      require_session_binding: true, allowed_methods: ["totp"],
    )
    ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).at(now.to_i),
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      token.device_session_record!.revoke!

      assert_no_difference "actor.client_totp_credentials.count" do
        assert_raises(IdentityTotpCeremonyContract::Error) do
          IdentityTotpEnrollmentFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
            step_up_evidence: nil,
          )
        end
      end
      assert_not_predicate transaction.reload, :consumed?
    end
  end

  test "a superseded device token cannot finalize a verified TOTP enrollment" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @test_actors << actor
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "bootstrap",
      required_scope: "settings_totp", required_aal: "none", step_up_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
      require_session_binding: true, allowed_methods: ["totp"],
    )
    ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).at(now.to_i),
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      device = token.device_session_record!
      replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
      device.update!(current_refresh_token_id: replacement.id)

      assert_no_difference "actor.client_totp_credentials.count" do
        assert_raises(IdentityTotpCeremonyContract::Error) do
          IdentityTotpEnrollmentFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
            step_up_evidence: nil,
          )
        end
      end
      assert_not_predicate transaction.reload, :consumed?
    end
  end

  test "Base creates the confirmed credential once and retries return the same active credential without freshness" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @test_actors << actor
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
      required_scope: "settings_totp", required_aal: "none", step_up_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
      require_session_binding: true, allowed_methods: ["totp"],
    )
    ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "credential_registration_handoff",
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).at(now.to_i), title: "Authenticator",
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )

      OpBaseAppRecord.transaction do
        assert_raises(IdentityTotpEnrollmentFinalCommitter::TransactionConflict) do
          IdentityTotpEnrollmentFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
            step_up_evidence: step_up_evidence,
          )
        end
        raise ActiveRecord::Rollback
      end

      assert_equal "verified", transaction.reload.status
      assert_equal 0, actor.client_totp_credentials.count

      commits = []
      subscriber =
        ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          payload = event.payload
          next unless payload[:name].to_s.include?("TRANSACTION") && payload[:sql].to_s.start_with?("COMMIT")

          commits << payload[:connection]&.pool&.db_config&.name
        end
      credential = nil
      begin
        assert_difference("actor.client_totp_credentials.count", 1) do
          credential = IdentityTotpEnrollmentFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
            step_up_evidence: step_up_evidence,
          )
        end
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
      op_base_index = commits.index("op_base_app")
      zenith_index = commits.index("app_zenith")

      assert_not_nil op_base_index, "the enrollment consumption must commit in op_base_app"
      assert_not_nil zenith_index, "the TOTP credential must commit in app_zenith"
      assert_operator op_base_index, :<, zenith_index, "OP consumption must commit before the credential"

      assert_predicate credential, :active?
      assert_equal candidate.private_key, credential.private_key
      assert_equal candidate.reload.last_otp_at, credential.last_otp_at
      assert_equal "Authenticator", credential.title
      assert_equal "consumed", transaction.reload.status
      assert_equal credential.public_id, transaction.verified_credential_ref
      assert_equal "none", transaction.aal
      assert_not transaction.phishing_resistant
      assert_equal now, transaction.consumed_at
      assert_equal now, candidate.consumed_at
      assert_predicate ceremony.reload, :completed?
      child = ClientTotpCeremonyTransaction.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)

      assert_predicate child, :consumed?
      assert_equal transaction.result_jti, child.result_jti
      assert_no_difference("actor.client_totp_credentials.count") do
        repeated = IdentityTotpEnrollmentFinalCommitter.call!(
          actor: actor, token: token, transaction: transaction, raw_result: result.code,
          step_up_evidence: step_up_evidence,
        )

        assert_equal credential.id, repeated.id
      end
      OpBaseAppRecord.transaction do
        assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
      end
      credential.update!(user_totp_credential_status_id: ClientTotpCredentialStatus::REVOKED)

      assert_raises(IdentityTotpCeremonyContract::Error) do
        IdentityTotpEnrollmentFinalCommitter.call!(
          actor: actor, token: token, transaction: transaction, raw_result: result.code,
          step_up_evidence: step_up_evidence,
        )
      end
      assert_predicate credential.reload, :revoked?
    end
  end

  test "a consumed registration with no principal credential fails closed instead of recreating one" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @test_actors << actor
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "bootstrap",
      required_scope: "settings_totp", required_aal: "none", step_up_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
      require_session_binding: true, allowed_methods: ["totp"],
    )
    ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).at(now.to_i),
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      client_connection = Client.lease_connection
      failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected Zenith commit failure" }

      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        client_connection.stub(:commit_db_transaction, failed_commit) do
          IdentityTotpEnrollmentFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
            step_up_evidence: nil,
          )
        end
      end

      assert_no_difference("actor.client_totp_credentials.count") do
        assert_raises(IdentityTotpCeremonyContract::Error) do
          IdentityTotpEnrollmentFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
            step_up_evidence: nil,
          )
        end
      end
      assert_equal "consumed", transaction.reload.status
      assert_not_nil candidate.reload.consumed_at
      assert_predicate ceremony.reload, :completed?
      assert_nil token.reload.last_step_up_at
    end
  end

  test "a principal write failure retains the unconsumed proof and candidate for a safe retry" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @test_actors << actor
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
      required_scope: "settings_totp", required_aal: "none", step_up_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
      require_session_binding: true, allowed_methods: ["totp"],
    )
    ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "credential_registration_handoff",
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).at(now.to_i),
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      op_connection = OpBaseAppRecord.lease_connection
      failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected OP commit failure" }

      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        op_connection.stub(:commit_db_transaction, failed_commit) do
          IdentityTotpEnrollmentFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
            step_up_evidence: step_up_evidence,
          )
        end
      end

      assert_equal "verified", transaction.reload.status
      assert_nil candidate.reload.consumed_at
      assert_not_predicate ceremony.reload, :completed?
      assert_equal 0, actor.client_totp_credentials.count
      token.reload

      # The principal persistence boundary fails while the real ticket locks and validation run.
      unavailable = ->(**_attributes) { raise ActiveRecord::ConnectionNotEstablished, "principal unavailable" }

      ClientTotpCredential.stub(:create_for_user!, unavailable) do
        assert_raises(ActiveRecord::ConnectionNotEstablished) do
          IdentityTotpEnrollmentFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
            step_up_evidence: step_up_evidence,
          )
        end
      end

      assert_equal "verified", transaction.reload.status
      assert_nil transaction.verified_credential_ref
      assert_nil candidate.reload.consumed_at
      assert_not_predicate ceremony.reload, :completed?
      assert_equal 0, actor.client_totp_credentials.count
      OpBaseAppRecord.transaction do
        assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
      end
      credential = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: transaction, raw_result: result.code,
        step_up_evidence: step_up_evidence,
      )

      assert_predicate credential, :active?
      assert_equal "consumed", transaction.reload.status
      OpBaseAppRecord.transaction do
        assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
      end
    end
  end

  test "Base bootstrap finalization remains independent of OP Step-Up evidence" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @test_actors << actor
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    root_authentication_state = token.attributes.slice("root_login_established_at", "established_authentication_method")
    bootstrap_requirement = StepUpRequirement.new(
      step_up_required: false, scope: "settings_birthdate", purpose: "bootstrap",
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil, audience: "step_up:app", allowed_methods: [:totp],
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor,
      token: token,
      requirement: bootstrap_requirement,
      return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    ).transaction
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    credential = nil
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).at(now.to_i),
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      credential = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: transaction, raw_result: result.code,
        step_up_evidence: nil,
      )
    end

    assert_predicate credential, :active?
    assert_equal "/identity/birthdate", transaction.reload.return_to
    assert_equal "bootstrap", transaction.purpose
    assert_equal "none", transaction.aal
    assert_equal root_authentication_state, token.reload.attributes.slice(*root_authentication_state.keys)
  end
end
