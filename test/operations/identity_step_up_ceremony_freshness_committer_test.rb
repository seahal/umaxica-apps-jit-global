# frozen_string_literal: true

require "test_helper"

# Verification evidence here is synthetic; signature verification is exercised by the Passkey
# committer tests. This boundary verifies atomic Base finalization and transport replay.
class IdentityStepUpCeremonyFreshnessCommitterTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @actor = clients(:one)
    @credential = @actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
    @token = ClientToken.create!(user: @actor)
    @requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
      audience: "step_up:app", session_binding: @token.public_id, token_binding: @token.public_id,
      require_session_binding: true, actor_ref: @actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    @transaction = issue_base_step_up_admission!(
      actor: @actor, token: @token, requirement: @requirement, return_to: "/identity/birthdate",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: @token,
    ).transaction
    @transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: @credential.public_id,
    )
    @ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )
    @issuance = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction, ceremony_session_ref: @ceremony.id.to_s,
    )
  end

  test "Base atomically consumes the exact ticket and retains the original event on replay" do
    event = @transaction.verified_at
    2.times do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
        raw_result: @issuance.code,
      )

      assert_equal "consumed", @transaction.reload.status
      assert_equal event, @token.reload.last_step_up_at
      assert_equal "settings_birthdate", @token.last_step_up_scope
      assert_predicate @ceremony.reload, :completed?
    end
  end

  test "each realm full reauthentication replaces its root once and refuses revoked-device result replay" do
    %w(app com org).each do |surface|
      actor, token, credential =
        case surface
        when "app"
          actor = Client.create!(status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(user: actor),
           actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public"),]
        when "com"
          actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          VisitorEmail.create!(
            visitor: actor, address: "reauth-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
            visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          ).finalize_binding!
          [actor, VisitorToken.create!(visitor: actor),
           actor.visitor_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public"),]
        when "org"
          actor = Operator.create!
          [actor, OperatorToken.create!(staff: actor),
           actor.operator_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public"),]
        end
      requirement = StepUpRequirement.new(
        scope: "settings_passkey", purpose: "reauthentication", step_up_required: true, allowed_methods: [:passkey],
        phishing_resistant_required: true, user_verification_required: true, full_reauthentication_required: true,
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      issuance = BaseStepUpAdmissionIssuer.call!(
        actor:, token:, requirement:, return_to: "/identity/passkeys",
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: token,
      )
      transaction = issuance.transaction
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      auth_model = binding.class.auth_admission_session_class
      attached, raw_sid = auth_model.issue!
      binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
      binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface:, expected_intent: "reauthentication", binding:, raw_auth_sid: raw_sid,
      )
      ceremony, = auth_model.rotate_and_admit!(
        admission_purpose: "reauthentication_handoff", previous_raw_sid: raw_sid,
        step_up_ceremony_transaction_ref: transaction.transaction_id,
      )
      binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
      # Synthetic evidence isolates Base root replacement; WebAuthn cryptography has separate committer tests.
      credential_ref = (surface == "org") ? credential.external_id : credential.public_id
      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
        verified_at: transaction.class.database_now, verified_credential_ref: credential_ref,
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(transaction:, ceremony_session_ref: ceremony.id.to_s)
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor:, token:, transaction:, requirement:, result_reference: result.reference,
      )
      replacement = token.class.find(token.device_session.reload.current_refresh_token_id)

      assert_equal ["consumed", true, true, true],
                   [transaction.reload.status, token.reload.rotated_at.present?, replacement.id != token.id,
                    ceremony.reload.completed?,]
      retry_requirement = StepUpRequirement.new(
        **requirement.to_h.merge(session_binding: replacement.public_id, token_binding: replacement.public_id),
      )
      assert_no_difference -> { token.class.count } do
        IdentityStepUpCeremonyFreshnessCommitter.call!(
          actor:, token: replacement, transaction:, requirement: retry_requirement, result_reference: result.reference,
        )
      end
      event = replacement.reload.last_step_up_at
      replacement.device_session.revoke!(reason: "user_logout")

      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyFreshnessCommitter.call!(
          actor:, token: replacement, transaction:, requirement: retry_requirement, result_reference: result.reference,
        )
      end
      assert_equal ["consumed", event], [transaction.reload.status, replacement.reload.last_step_up_at]
    end
  end

  [-1, 0, 1].each do |microseconds|
    test "cancellation evaluates token expiry at writer time #{microseconds} microseconds from deadline" do
      application_now = ClientStepUpCeremonyTransaction.database_now
      deadline = application_now + 1.second
      @token.update!(discard_at: deadline)
      decision_time = deadline + Rational(microseconds, 1_000_000)

      travel_to(application_now) do
        ClientStepUpCeremonyTransaction.stub(:database_now, decision_time) do
          if microseconds < 0
            assert IdentityStepUpCeremonyCancellationCommitter.call!(
              actor: @actor, token: @token, transaction: @transaction,
            )
            assert_equal "canceled", @transaction.reload.status
            assert_not_nil @ceremony.reload.cancelled_at
          else
            assert_raises(IdentityStepUpCeremonyContract::Error) do
              IdentityStepUpCeremonyCancellationCommitter.call!(
                actor: @actor, token: @token, transaction: @transaction,
              )
            end
            assert_equal "verified", @transaction.reload.status
            assert_nil @ceremony.reload.cancelled_at
          end

          assert_nil @token.reload.last_step_up_at
        end
      end
    end

    test "Base evaluates token expiry at writer time #{microseconds} microseconds from deadline" do
      application_now = ClientStepUpCeremonyTransaction.database_now
      deadline = application_now + 1.second
      @token.update!(discard_at: deadline)
      decision_time = deadline + Rational(microseconds, 1_000_000)

      travel_to(application_now) do
        ClientStepUpCeremonyTransaction.stub(:database_now, decision_time) do
          if microseconds < 0
            IdentityStepUpCeremonyFreshnessCommitter.call!(
              actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
              raw_result: @issuance.code,
            )

            assert_equal "consumed", @transaction.reload.status
          else
            assert_raises(IdentityStepUpCeremonyContract::Error) do
              IdentityStepUpCeremonyFreshnessCommitter.call!(
                actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
                raw_result: @issuance.code,
              )
            end
            assert_equal "verified", @transaction.reload.status
            assert_nil @token.reload.last_step_up_at
            assert_not_predicate @ceremony.reload, :completed?
          end
        end
      end
    end

    test "Resolver evaluates token expiry at requested time #{microseconds} microseconds from deadline" do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
        raw_result: @issuance.code,
      )
      application_now = ClientStepUpCeremonyTransaction.database_now
      deadline = application_now + 1.second
      @token.update!(discard_at: deadline)

      travel_to(application_now) do
        result = StepUpResolver.call(
          token: @token, requirement: @requirement,
          now: deadline + Rational(microseconds, 1_000_000),
        )

        assert_equal microseconds < 0, result.usable_token?
        assert_equal microseconds < 0, result.satisfied?
      end
    end
  end

  test "revoking the verified credential before Base completion prevents freshness" do
    @credential.update!(discard_at: Time.current)
    assert_raises(ActiveRecord::RecordNotFound) do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
        raw_result: @issuance.code,
      )
    end
    assert_equal "verified", @transaction.reload.status
    assert_nil @token.reload.last_step_up_at
    assert_not_predicate @ceremony.reload, :completed?
  end

  test "a strengthened current resource policy cannot reuse the admitted transaction" do
    changed_requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
      audience: "step_up:app", session_binding: @token.public_id, token_binding: @token.public_id,
      require_session_binding: true, actor_ref: @actor.public_id, resource_ref: "different-resource",
      tenant_ref: nil,
    )

    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: changed_requirement,
        raw_result: @issuance.code,
      )
    end
    assert_equal "verified", @transaction.reload.status
    assert_nil @token.reload.last_step_up_at
    assert_not_predicate @ceremony.reload, :completed?
  end

  test "logout before Base completion revokes evidence and rejects the pending result" do
    @token.revoke!

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
        raw_result: @issuance.code,
      )
    end

    assert_predicate @token.reload, :revoked?
    assert_nil @token.last_step_up_at
    assert_equal "revoked", @transaction.reload.status
    assert_not_nil @ceremony.reload.revoked_at
    assert_not_predicate @ceremony, :completed?
  end

  test "verification without required user verification cannot become Base evidence" do
    IdentityStepUpCeremonyCancellationCommitter.call!(actor: @actor, token: @token, transaction: @transaction)
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: true,
      full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
      audience: "step_up:app", session_binding: @token.public_id, token_binding: @token.public_id,
      require_session_binding: true, actor_ref: @actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    transaction = issue_base_step_up_admission!(
      actor: @actor, token: @token, requirement: requirement, return_to: "/identity/birthdate",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: @token,
    ).transaction
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true,
        user_verified: false,
        verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: @credential.public_id,
      )
    end
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, ceremony_session_ref: ceremony.id.to_s)
    end

    assert_equal "pending", transaction.reload.status
    assert_nil transaction.verified_at
    assert_nil transaction.consumed_at
    assert_nil @token.reload.last_step_up_at
    assert_not_predicate ceremony.reload, :completed?
  end

  test "cancellation before Base completion rejects the pending result without revoking the root session" do
    assert IdentityStepUpCeremonyCancellationCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction,
    )

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
        raw_result: @issuance.code,
      )
    end

    assert_predicate @token.reload, :currently_usable?
    assert_nil @token.last_step_up_at
    assert_equal "canceled", @transaction.reload.status
    assert_not_nil @ceremony.reload.cancelled_at
    assert_not_predicate @ceremony, :completed?
  end

  test "cancellation after Base completion refuses to rewrite the finalized authority" do
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
      raw_result: @issuance.code,
    )
    original_event = @token.reload.last_step_up_at
    consumed_at = @transaction.reload.consumed_at

    assert_not IdentityStepUpCeremonyCancellationCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction,
    )

    assert_predicate @token.reload, :currently_usable?
    assert_equal original_event, @token.last_step_up_at
    assert_equal consumed_at, @transaction.reload.consumed_at
    assert_equal "consumed", @transaction.status
    assert_nil @transaction.canceled_at
    assert_predicate @ceremony.reload, :completed?
    assert_nil @ceremony.cancelled_at
  end

  test "logout after Base completion clears freshness and rejects a finalized result retry" do
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
      raw_result: @issuance.code,
    )

    assert_equal @transaction.verified_at, @token.reload.last_step_up_at
    @token.revoke!

    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
        raw_result: @issuance.code,
      )
    end

    assert_predicate @token.reload, :revoked?
    assert_nil @token.last_step_up_at
    assert_equal "consumed", @transaction.reload.status
    assert_predicate @ceremony.reload, :completed?
    assert_not StepUpResolver.call(token: @token, requirement: @requirement).satisfied?
  end

  %w(client_tokens client_step_up_ceremony_transactions client_auth_ceremony_sessions).each do |table|
    test "failure after updating #{table} rolls back Base authority and permits the same result retry" do
      event = @transaction.verified_at
      injected = 0
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          if payload.fetch(:sql).start_with?("UPDATE \"#{table}\"")
            injected += 1
            raise ActiveRecord::StatementInvalid, "injected Base finalization write failure"
          end
        end

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
            raw_result: @issuance.code,
          )
        end
      end

      assert_equal 1, injected
      assert_nil @token.reload.last_step_up_at
      assert_equal "verified", @transaction.reload.status
      assert_nil @transaction.consumed_at
      assert_not_predicate @ceremony.reload, :completed?
      assert_predicate @ceremony, :admitted?

      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
        raw_result: @issuance.code,
      )

      assert_equal event, @token.reload.last_step_up_at
      assert_equal "consumed", @transaction.reload.status
      assert_predicate @ceremony.reload, :completed?
    end
  end
end
