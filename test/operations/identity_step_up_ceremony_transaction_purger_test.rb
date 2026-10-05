# frozen_string_literal: true

require "test_helper"

class IdentityStepUpCeremonyTransactionPurgerTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  fixtures :clients, :client_statuses, :client_visibilities

  test "a failure after deleting continuity rolls back the entire parent cohort" do
    now = Time.current
    parent = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "fault-actor", session_ref: "fault-session", required_scope: "settings_passkey",
      required_aal: "none", allowed_methods: ["passkey"], now: now - 9.days, expires_at: now - 8.days,
    )
    continuity, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id,
      now: now - 9.days,
    )
    injected = 0
    subscriber =
      lambda do |_name, _start, _finish, _id, payload|
        if payload.fetch(:sql).start_with?('DELETE FROM "client_auth_ceremony_sessions"')
          injected += 1
          raise ActiveRecord::StatementInvalid, "injected failure after continuity deletion"
        end
      end

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        IdentityStepUpCeremonyTransactionPurger.new(now: now).call
      end
    end

    assert_equal 1, injected
    assert ClientStepUpCeremonyTransaction.exists?(parent.id)
    assert ClientAuthCeremonySession.exists?(continuity.id)
    assert_not continuity.reload.active?(now: now)
    assert_equal 1, IdentityStepUpCeremonyTransactionPurger.new(now: now).call.fetch(:app)
    assert_not ClientStepUpCeremonyTransaction.exists?(parent.id)
    assert_not ClientAuthCeremonySession.exists?(continuity.id)
  end

  test "a recently canceled or revoked parent retains its terminal record after the original expiry" do
    now = Time.current
    [
      { status: "canceled", canceled_at: now - 1.day },
      { status: "revoked", revoked_at: now - 1.day },
    ].each do |terminal_state|
      parent = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: "retention-actor", session_ref: "retention-session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], now: now - 9.days, expires_at: now - 8.days,
      )
      parent.update!(terminal_state)

      result = IdentityStepUpCeremonyTransactionPurger.new(now: now).call

      assert_equal 0, result.fetch(:app)
      assert ClientStepUpCeremonyTransaction.exists?(parent.id)
    end
  end

  test "purging an old parent retains it while its bound continuity remains inside retention" do
    now = Time.current
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "retention-actor", session_ref: "retention-session", required_scope: "settings_passkey",
      required_aal: "none", allowed_methods: ["passkey"], now: now - 9.days,
      expires_at: now - 8.days,
    )
    continuity, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      now: now - 1.day,
    )

    result = IdentityStepUpCeremonyTransactionPurger.new(now: now).call

    assert_equal 0, result.fetch(:app)
    assert ClientStepUpCeremonyTransaction.exists?(transaction.id)
    assert ClientAuthCeremonySession.exists?(continuity.id)
  end

  test "a retained StepUpSession prevents parent deletion until its explicit purge deadline" do
    now = Time.current
    token = ClientToken.create!(user: clients(:one), created_at: now - 9.days)
    parent = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: clients(:one).public_id, session_ref: token.public_id, required_scope: "settings_passkey",
      required_aal: "none", allowed_methods: ["passkey"], now: now - 9.days, expires_at: now - 8.days,
    )
    session = ClientStepUpSession.create!(
      user_token: token, scope: parent.required_scope, return_to: "/identity/passkeys", status: "PENDING",
      step_up_ceremony_transaction_ref: parent.transaction_id, created_at: now - 9.days,
      discard_at: now - 8.days, purge_eligible_at: Float::INFINITY,
    )

    assert_equal 0, IdentityStepUpCeremonyTransactionPurger.new(now: now).call.fetch(:app)
    assert ClientStepUpCeremonyTransaction.exists?(parent.id)
    assert ClientStepUpSession.exists?(session.id)
    session.update!(purge_eligible_at: now)

    assert_equal 1, IdentityStepUpCeremonyTransactionPurger.new(now: now).call.fetch(:app)
    assert_not ClientStepUpCeremonyTransaction.exists?(parent.id)
    assert_not ClientStepUpSession.exists?(session.id)
    assert ClientToken.exists?(token.id)
  end

  test "expired APP TOTP child and encrypted candidate are collected before their registration parent" do
    now = Time.current
    parent = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "retention-actor", session_ref: "retention-session", required_scope: "settings_totp",
      required_aal: "none", allowed_methods: ["totp"], purpose: "bootstrap",
      now: now - 9.days, expires_at: now - 8.days,
    )
    candidate = IdentityTotpCeremonyCandidate.create!(
      ref: SecureRandom.uuid, digest: Digest::SHA256.hexdigest("JBSWY3DPEHPK3PXP"), surface: "app",
      actor_ref: parent.actor_ref, session_ref: parent.session_ref,
      private_key: "JBSWY3DPEHPK3PXP", step_up_ceremony_transaction_ref: parent.transaction_id,
      expires_at: now - 8.days, created_at: now - 9.days,
    )
    child = ClientTotpCeremonyTransaction.create!(
      transaction_id: SecureRandom.uuid, grant_jti: SecureRandom.uuid,
      surface: "app", actor_ref: parent.actor_ref, session_ref: parent.session_ref, operation: "registration",
      credential_candidate_ref: candidate.ref, credential_candidate_digest: candidate.digest,
      step_up_ceremony_transaction_ref: parent.transaction_id, expires_at: now - 8.days, created_at: now - 9.days,
    )

    result = IdentityStepUpCeremonyTransactionPurger.new(now: now).call

    assert_equal 1, result.fetch(:app)
    assert_not ClientStepUpCeremonyTransaction.exists?(parent.id)
    assert_not ClientTotpCeremonyTransaction.exists?(child.id)
    assert_not IdentityTotpCeremonyCandidate.exists?(candidate.id)
  end

  test "continuity retention is preserved just before eligibility and purged at and after eligibility" do
    now = Time.current.change(usec: 0)
    cutoff = now - StepUpCeremonyTransactionable::RETENTION_PERIOD
    [-1, 0, 1].each do |microseconds|
      parent = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: "retention-actor", session_ref: "retention-session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], now: now - 9.days, expires_at: now - 8.days,
      )
      continuity, = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id,
        now: cutoff - AuthCeremonySession::DEFAULT_TTL + Rational(microseconds, 1_000_000),
      )
      result = IdentityStepUpCeremonyTransactionPurger.new(now: now).call

      assert_equal (microseconds <= 0) ? 1 : 0, result.fetch(:app)
      assert_equal microseconds.positive?, ClientStepUpCeremonyTransaction.exists?(parent.id)
      assert_equal microseconds.positive?, ClientAuthCeremonySession.exists?(continuity.id)
    end
  end

  test "eligible expired continuity is removed before its parent on every surface and cannot reappear" do
    now = Time.current
    [
      [ClientStepUpCeremonyTransaction, ClientAuthCeremonySession, :app],
      [VisitorStepUpCeremonyTransaction, VisitorAuthCeremonySession, :com],
      [OperatorStepUpCeremonyTransaction, OperatorAuthCeremonySession, :org],
    ].each do |parent_model, continuity_model, surface|
      parent = parent_model.create_transaction!(
        actor_ref: "retention-actor", session_ref: "retention-session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], now: now - 9.days, expires_at: now - 8.days,
      )
      continuity, = continuity_model.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id,
        now: now - 9.days,
      )

      result = IdentityStepUpCeremonyTransactionPurger.new(now: now).call

      assert_equal 1, result.fetch(surface)
      assert_not parent_model.exists?(parent.id)
      assert_not continuity_model.exists?(continuity.id)
      assert_equal 0, IdentityStepUpCeremonyTransactionPurger.new(now: now).call.fetch(surface)
    end
  end
end
