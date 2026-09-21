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
    transaction = ClientSessionLimitResolutionTransaction.new(status: "pending", expires_at: 1.minute.from_now)

    assert_predicate transaction, :pending?
    transaction.status = "session_selected"

    assert_predicate transaction, :session_selected?
    transaction.status = "expired"

    assert_predicate transaction, :expired?

    updates = []
    transaction.stub(:update!, ->(attributes) { updates << attributes }) do
      now = Time.current
      transaction.mark_resolved!(now: now)

      assert_equal({ resolved_at: now, status: "resolved" }, updates.last)
    end
  end

  test "session limit issuance refreshes an existing active transaction" do
    existing = Struct.new(:audit_context) do
      attr_reader :updates

      def update!(attributes)
        @updates = attributes
      end
    end.new({ "existing" => true })
    relation = Object.new
    relation.define_singleton_method(:active_at) { |_now| self }
    relation.define_singleton_method(:find_by) { |**_attributes| existing }
    actor = Client.new(public_id: "client-public-id")
    oidc_transaction = Struct.new(:id).new(123)

    ClientSessionLimitResolutionTransaction.stub(:open_status, relation) do
      issuance = ClientSessionLimitResolutionTransaction.issue_for_oidc!(
        actor: actor,
        oidc_transaction: oidc_transaction,
        audit_context: { "new" => true },
      )

      assert_same existing, issuance.transaction
      assert_equal({ "existing" => true, "new" => true }, existing.updates.fetch(:audit_context))
    end
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
    sign_in_calls = []
    sign_in.stub(:complete_sign_in!, ->(**options) { sign_in_calls << options }) do
      now = Time.current
      sign_in.advance_sign_in_to_dashboard!(now: now)

      assert_equal({ step: "dashboard", now: now }, sign_in_calls.last)
    end
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
    assert_includes transaction.errors[:expected_step], "is not valid for the origin surface"
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
      lookup_digest: "digest",
      safe_prefix: "prefix",
    )

    assert_not credential.valid?
    assert_includes credential.errors.details[:secret_kind], { error: "is invalid" }
    assert_includes credential.errors.details[:usage_policy], { error: "is invalid" }
  end
end
