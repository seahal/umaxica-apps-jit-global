# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

# Bootstrap passkey registration consumes the candidate, registration transaction, and ceremony
# in one OP commit without requiring Step-Up evidence. The credential and its audit commit
# separately in Zenith. This file pins both the
# commit order and the crash-window recovery: a retry whose zenith credential is missing must
# refuse without creating a second credential from the consumed candidate.
class IdentityPasskeyRegistrationCommitOrderTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  # The operation commits per connection inside one call, so the harness transaction would hide
  # the commit sequence. Non-transactional runs keep explicit teardown.
  self.use_transactional_tests = false

  fixtures :client_statuses

  setup do
    @actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @token = ClientToken.create!(authentication_epoch: 0, user: @actor, root_login_established_at: Time.current)
    @requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false, allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: @actor.public_id,
      resource_ref: nil, tenant_ref: nil,
      audience: "step_up:app", session_binding: @token.public_id, token_binding: @token.public_id,
      require_session_binding: true,
    )
    @transaction = BaseStepUpAdmissionIssuer.call!(
      actor: @actor, token: @token, requirement: @requirement, return_to: "/identity/birthdate",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: @token,
    ).transaction
    @record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: @transaction.transaction_id)
    @ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )
    @fake = WebAuthn::FakeClient.new("https://auth.umaxica.app", encoding: :base64url)
    @config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: @fake.origin)
    @challenge = SecureRandom.urlsafe_base64(32)
    @reference = @record.issue_bound_passkey_registration_challenge!(
      transaction: @transaction, challenge: @challenge, rp_id: @config.rp_id, origin: @config.origin,
    )
    attestation = @fake.create(challenge: @challenge, user_verified: true)
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: attestation, description: "Laptop",
    )
    @result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction.reload, ceremony_session_ref: @ceremony.id.to_s,
    )
  end

  teardown do
    actor_ids = [@actor&.id].compact
    actor_refs = Client.where(id: actor_ids).pluck(:public_id)
    token_ids = ClientToken.where(user_id: actor_ids).pluck(:id)
    OpAppGrant.where(client_token_id: token_ids).delete_all
    ClientPasskeyAuditOutbox.where(actor_ref: actor_refs).delete_all
    ClientPasskey.where(user_id: actor_ids).delete_all
    IdentityPasskeyCeremonyCandidate
      .where(step_up_ceremony_transaction_ref: @transaction&.transaction_id)&.destroy_all
    ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: @transaction&.id).destroy_all
    ClientStepUpSession.where(step_up_ceremony_transaction_ref: @transaction&.transaction_id).delete_all
    @ceremony&.destroy!
    ClientStepUpCeremonyTransaction.where(id: @transaction&.id).delete_all
    ClientDeviceSession.where(user_id: actor_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: actor_ids).delete_all
    ClientDeviceSession.where(user_id: actor_ids).delete_all
    ClientAuthorityLock.where(client_id: actor_ids).delete_all
    ClientPreference.where(client_id: actor_ids).destroy_all
    ClientAccount.where(user_id: actor_ids).delete_all
    Client.where(id: actor_ids).delete_all
  end

  test "the consumption commit precedes the zenith credential commit" do
    commits = []
    subscriber =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        payload = event.payload
        next unless payload[:name].to_s.include?("TRANSACTION") && payload[:sql].to_s.start_with?("COMMIT")

        commits << payload[:connection]&.pool&.db_config&.name
      end

    identity = IdentityPasskeyRegistrationFinalCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
      step_up_evidence: nil,
    )
    ActiveSupport::Notifications.unsubscribe(subscriber)

    # The per-connection commit teardown: OP candidate, transaction, and ceremony writes commit
    # before the Zenith credential is durable; a Zenith commit
    # inside the call must never precede an op_base one.
    op_base_index = commits.index("op_base_app")
    zenith_index = commits.index("app_zenith")

    assert_not_nil op_base_index, "the consumption must open and commit its own op_base transaction"
    assert_not_nil zenith_index, "the credential must open and commit its own zenith transaction"
    assert_operator op_base_index, :<, zenith_index, "commit order: consumption commit first"
    assert_operator commits.rindex("op_base_app"), :<, zenith_index,
                    "no zenith commit inside the call may precede an op_base commit"

    assert_equal "consumed", identity && @transaction.reload.status
    assert_equal 1, @actor.client_passkeys.count
  end

  test "an OP commit failure before consumption leaves the candidate, ticket, ceremony and credential unchanged" do
    op_connection = OpBaseAppRecord.lease_connection
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected OP commit failure" }

    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      op_connection.stub(:commit_db_transaction, failed_commit) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
          step_up_evidence: nil,
        )
      end
    end

    candidate = IdentityPasskeyCeremonyCandidate.find_by!(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )

    assert_equal "verified", @transaction.reload.status
    assert_nil candidate.consumed_at
    assert_not_predicate @ceremony.reload, :completed?
    assert_equal 0, @actor.reload.client_passkeys.count
    assert_equal 0, ClientPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).count
  end

  test "a Zenith commit failure after OP consumption retains consumption without a credential or audit" do
    client_connection = Client.lease_connection
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected Zenith commit failure" }

    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      client_connection.stub(:commit_db_transaction, failed_commit) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
          step_up_evidence: nil,
        )
      end
    end

    candidate = IdentityPasskeyCeremonyCandidate.find_by!(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )

    assert_equal "consumed", @transaction.reload.status
    assert_not_nil candidate.consumed_at
    assert_predicate @ceremony.reload, :completed?
    assert_equal 0, @actor.reload.client_passkeys.count
    assert_equal 0, ClientPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).count

    assert_raises(IdentityPasskeyCeremonyContract::Error) do
      IdentityPasskeyRegistrationFinalCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
        step_up_evidence: nil,
      )
    end
    assert_equal 0, @actor.reload.client_passkeys.count
  end

  test "a lost OP commit acknowledgement leaves consumption committed and Zenith unmodified" do
    op_connection = OpBaseAppRecord.lease_connection
    commit = op_connection.method(:commit_db_transaction)
    lose_acknowledgement =
      lambda do
        commit.call
        op_connection.disconnect!
        raise PG::ConnectionBad, "injected lost OP commit acknowledgement"
      end

    assert_raises(PG::ConnectionBad) do
      op_connection.stub(:commit_db_transaction, lose_acknowledgement) do
        op_connection.stub(:rollback_db_transaction, -> { }) do
          IdentityPasskeyRegistrationFinalCommitter.call!(
            actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
            step_up_evidence: nil,
          )
        end
      end
    end

    candidate = IdentityPasskeyCeremonyCandidate.find_by!(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )

    assert_equal "consumed", @transaction.reload.status
    assert_not_nil candidate.consumed_at
    assert_predicate @ceremony.reload, :completed?
    assert_equal 0, @actor.reload.client_passkeys.count
    assert_equal 0, ClientPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).count
  end

  test "a lost Zenith commit acknowledgement converges to the committed credential on retry" do
    client_connection = Client.lease_connection
    commit = client_connection.method(:commit_db_transaction)
    lose_acknowledgement =
      lambda do
        commit.call
        client_connection.disconnect!
        raise PG::ConnectionBad, "injected lost Zenith commit acknowledgement"
      end

    assert_raises(PG::ConnectionBad) do
      client_connection.stub(:commit_db_transaction, lose_acknowledgement) do
        client_connection.stub(:rollback_db_transaction, -> { }) do
          IdentityPasskeyRegistrationFinalCommitter.call!(
            actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
            step_up_evidence: nil,
          )
        end
      end
    end

    assert_equal "consumed", @transaction.reload.status
    candidate = IdentityPasskeyCeremonyCandidate.find_by!(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )
    first = @actor.reload.client_passkeys.find_by!(webauthn_id: candidate.webauthn_id)

    assert_equal 1, ClientPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).count
    retry_result = IdentityPasskeyRegistrationFinalCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
      step_up_evidence: nil,
    )

    assert_equal first.id, retry_result.id
    assert_equal 1, @actor.reload.client_passkeys.count
    assert_equal 1, ClientPasskeyAuditOutbox.where(operation_ref: @transaction.transaction_id).count
  end

  test "an enclosing OP transaction is refused before the candidate or credential changes" do
    OpBaseAppRecord.transaction(joinable: false) do
      assert_raises(IdentityPasskeyRegistrationFinalCommitter::TransactionConflict) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
          step_up_evidence: nil,
        )
      end
    end

    assert_equal "verified", @transaction.reload.status
    assert_nil IdentityPasskeyCeremonyCandidate.find_by(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    ).consumed_at
    assert_equal 0, @actor.reload.client_passkeys.count
  end

  test "a retry whose lone credential vanished refuses without double registration" do
    IdentityPasskeyRegistrationFinalCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
      step_up_evidence: nil,
    )
    credential = @actor.reload.client_passkeys.take

    assert credential, "precondition: the first finalization created the credential"
    ClientPasskey.where(id: credential.id).delete_all

    assert_not ClientPasskey.exists?(id: credential.id),
               "precondition: the zenith credential is gone"

    assert_raises(IdentityPasskeyCeremonyContract::Error) do
      IdentityPasskeyRegistrationFinalCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, raw_result: @result.code,
        step_up_evidence: nil,
      )
    end

    assert_equal 0, @actor.reload.client_passkeys.count,
                 "the consumed candidate must not create a second credential"
    assert_equal "consumed", @transaction.reload.status
  end
end
