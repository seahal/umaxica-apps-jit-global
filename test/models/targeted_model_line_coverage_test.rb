# typed: false
# frozen_string_literal: true

require "test_helper"

class TargetedModelLineCoverageTest < ActiveSupport::TestCase
  class AbstractOidcAuthorization < ApplicationRecord
    self.abstract_class = true
    include OidcAuthorizationTransactionable
  end

  class AbstractStepUpCeremony < ApplicationRecord
    self.abstract_class = true
    include StepUpCeremonyTransactionable
  end

  test "withdrawal occurrence helpers reject unsupported types and digest optional values" do
    unsupported = Object.new

    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.occurrence_class_for(unsupported) }
    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.occurrence_status_id_for(String) }
    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.occurrence_status_class_for(String) }
    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.surface_for(unsupported) }
    assert_nil WithdrawalOccurrenceRecording.digest_optional(nil)
    assert_equal Digest::SHA256.hexdigest("agent"), WithdrawalOccurrenceRecording.digest_optional("agent")
  end

  test "session limit transaction predicates and write helpers cover every state" do
    states = {
      ClientSessionLimitResolutionTransaction::PENDING => :pending?,
      ClientSessionLimitResolutionTransaction::SESSION_SELECTED => :session_selected?,
      ClientSessionLimitResolutionTransaction::RESOLVED => :resolved?,
      ClientSessionLimitResolutionTransaction::EXPIRED => :expired?,
      ClientSessionLimitResolutionTransaction::CANCELLED => :cancelled?,
    }

    states.each do |state, predicate|
      assert_predicate ClientSessionLimitResolutionTransaction.new(state_id: state), predicate
    end
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(
      principal_id: actor.id,
      state_id: ClientSignInFlowState::SESSION_ISSUANCE_PENDING,
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    digest = ClientSessionLimitResolutionTransaction.digest_challenge(SecureRandom.urlsafe_base64(32))
    issuance = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: flow,
      actor: actor,
      browser_binding_digest: digest,
    )
    record = issuance.transaction
    record.select_session!(
      actor: actor,
      challenge: issuance.challenge,
      session_ref: token.public_id,
      browser_binding_digest: digest,
    )

    assert_predicate record.reload, :session_selected?
    record.resolve!(actor: actor, challenge: issuance.challenge, browser_binding_digest: digest)

    assert_predicate record.reload, :resolved?
    assert_equal record.resolved_at, record.finalized_at
    assert_not_nil record.resolved_at
    assert_not_predicate token.reload, :currently_usable?
  end

  test "session limit issuance refreshes an existing active transaction" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(
      principal_id: actor.id,
      state_id: ClientSignInFlowState::SESSION_ISSUANCE_PENDING,
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
    )
    digest = ClientSessionLimitResolutionTransaction.digest_challenge(SecureRandom.urlsafe_base64(32))
    first = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: flow, actor: actor, browser_binding_digest: digest, audit_context: { "existing" => true },
    )
    second = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: flow, actor: actor, browser_binding_digest: digest, audit_context: { "new" => true },
    )

    assert_equal first.transaction.id, second.transaction.id
    assert_equal({ "existing" => true, "new" => true }, second.transaction.audit_context)
    assert_nil ClientSessionLimitResolutionTransaction.find_active_by_challenge(first.challenge)
    assert_equal second.transaction.id,
                 ClientSessionLimitResolutionTransaction.find_active_by_challenge(second.challenge).id
    assert_not_equal first.challenge, second.challenge
  end

  test "processor notification status helpers and pending scope are executable" do
    assert_equal "PENDING", ClientProcessorErasureNotification.status_name_for(
      ClientProcessorErasureNotification.status_id_for("PENDING"),
    )
    notification = ClientProcessorErasureNotification.new(
      status_id: ClientProcessorErasureNotification.status_id_for("PENDING"),
    )

    assert_predicate notification, :pending?
    assert_kind_of ActiveRecord::Relation, ClientProcessorErasureNotification.pending_for_processing
  end

  test "retention and privacy state helpers expose status names and predicates" do
    active_id = ClientRetentionHold.status_id_for("ACTIVE")

    assert_equal "ACTIVE", ClientRetentionHold.status_name_for(active_id)
    assert_predicate ClientRetentionHold.new(status_id: active_id, expires_at: nil), :active_at?

    received_id = ClientPrivacyRequest.status_id_for("RECEIVED")

    assert_equal "RECEIVED", ClientPrivacyRequest.status_name_for(received_id)
    blocking_id = ClientPrivacyRequest.status_id_for("VERIFIED")

    assert_predicate ClientPrivacyRequest.new(status_id: blocking_id), :recovery_blocking?
  end

  test "retention hold is inactive when released or expired" do
    released = ClientRetentionHold.new(
      status_id: ClientRetentionHold.status_id_for("RELEASED"),
      expires_at: nil,
    )
    expired = ClientRetentionHold.new(
      status_id: ClientRetentionHold.status_id_for("ACTIVE"),
      expires_at: 1.minute.ago,
    )

    assert_not_predicate released, :active_at?
    assert_not_predicate expired, :active_at?
  end

  test "simple public model mappings return their public ids and fallback owners" do
    assert_equal "passkey-id", ClientPasskey.new(public_id: "passkey-id").to_param
    assert_equal "request-id", OperatorLifecycleRequest.new(public_id: "request-id").to_param
    assert_equal ActiveRecord::Base, AbstractOidcAuthorization.connection_owner
    assert_equal ActiveRecord::Base, AbstractStepUpCeremony.connection_owner
  end

  test "flow sign in and sign out delegate their remaining public transitions" do
    sign_in = ClientSignInFlow.new
    assert_raises(FlowInvalidTransition) { sign_in.advance_sign_in_to_selector! }
    discard_calls = []
    sign_in.stub(:discard_cycle!, ->(**options) { discard_calls << options }) do
      sign_in.discard_sign_in!(now: Time.current)
    end

    assert_equal sign_in.purge_eligible_at, discard_calls.last.fetch(:purge_eligible_at)

    sign_out = ClientSignOutFlow.new(status_id: ClientSignOutFlow.status_id_for("NOTHING"))

    assert_predicate sign_out, :sign_out_nothing?
  end

  test "unknown oidc and step up stores use the base connection owner" do
    assert_equal ActiveRecord::Base, AbstractOidcAuthorization.connection_owner
    assert_equal ActiveRecord::Base, AbstractStepUpCeremony.connection_owner
  end

  test "logout transaction handles stale consumption and a disappearing lookup" do
    transaction = LogoutTransaction.new
    transaction.stub(:with_lock, -> { raise ActiveRecord::StaleObjectError }) do
      transaction.stub(:reload, transaction) do
        transaction.stub(:consumed?, true) do
          result = transaction.consume!(verifier: "verifier", issuer: "issuer", audience: "audience", purpose: "logout")

          assert_equal :consumed, result.status
        end
      end
    end

    LogoutTransaction.stub(:find_by, ->(**_attributes) { raise ActiveRecord::RecordNotFound }) do
      result = LogoutTransaction.consume_one_time_url_token!(
        raw_token: "public-id.verifier",
        issuer: "issuer",
        audience: "audience",
        purpose: "logout",
      )

      assert_equal :invalid, result.status
    end
  end

  test "acme logout predicates and origin validation cover unsupported states" do
    assert_raises(ArgumentError) { AcmeLogoutTransaction.step_sequence_for("unsupported") }
    assert_predicate AcmeLogoutTransaction.new(status: "initiated"), :initiated?
    assert_predicate AcmeLogoutTransaction.new(status: "in_progress"), :in_progress?

    transaction = AcmeLogoutTransaction.new(
      origin_surface: "sign",
      expected_step: "sign_cleared",
      initiating_client_id: "client-id",
      completion_url: "/done",
      status: "initiated",
      expires_at: 1.minute.from_now,
    )

    assert_not transaction.valid?
    assert_includes transaction.errors[:expected_step], "is not valid for the logout workflow"
  end

  test "unsupported email verification outcome is reported" do
    transaction = ClientEmailCeremonyTransaction.new(
      evp_outcome: "unsupported",
      evp_nonce_digest: "digest",
      evp_consumed_at: Time.current,
    )

    assert_not transaction.valid?
    assert_includes transaction.errors.details[:evp_outcome], { error: "is unsupported" }
  end

  test "new secret credential fields reject unsupported values" do
    credential = VisitorSecretCredential.new(
      secret_kind: "unsupported",
      usage_policy: "unsupported",
      safe_prefix: "prefix",
    )

    assert_not credential.valid?
    assert_includes credential.errors.details[:secret_kind], { error: "is invalid" }
    assert_includes credential.errors.details[:usage_policy], { error: "is invalid" }
  end
end
