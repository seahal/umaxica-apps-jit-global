# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAuthAdmissionCoordinatorTest < ActiveSupport::TestCase
  setup do
    skip "AUTH_STATE_REDIS_URL unset" if ENV["AUTH_STATE_REDIS_URL"].blank?
  end

  test "handoff consume is one-shot and bound to surface" do
    transaction = issue_transaction!

    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(transaction: transaction)
    payload = BaseAuthAdmissionCoordinator.consume_handoff!(
      raw_code: issuance.code,
      surface: "app",
      expected_intent: "sign_in",
    )

    assert_equal transaction.transaction_id, payload.fetch("subject_ref")
    assert_equal "app", payload.fetch("surface")
    assert_equal "client", payload.fetch("actor_type")

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_handoff!(
        raw_code: issuance.code,
        surface: "app",
        expected_intent: "sign_in",
      )
    end
  end

  test "result issuance returns only an opaque body token" do
    transaction = issue_transaction!
    OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "app",
      login_challenge: transaction.login_challenge,
      actor: clients(:one),
      session_ref: "session-ref",
      auth_method: "passkey",
      authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
    )
    issuance = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction.reload)

    assert_predicate issuance.code, :present?
    assert_not_respond_to issuance, :resume_url
    assert_no_match %r{https?://}, issuance.code
  end

  test "result issuance does not export an Auth session as Base session authority" do
    transaction = issue_transaction!
    store = PurposeCaptureStore.new

    OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "app",
      login_challenge: transaction.login_challenge,
      actor: clients(:one),
      session_ref: "session-ref",
      auth_method: "passkey",
      authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
    )

    BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction.reload, store: store)

    assert_equal transaction.transaction_id, store.options.fetch(:subject_ref)
    assert_nil store.options[:base_session_ref]
  end

  test "result issuance persists only the current generation digest and expiry" do
    transaction = issue_authenticated_transaction!
    store = PurposeCaptureStore.new

    issuance = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, store: store)
    persisted = transaction.reload

    assert_equal 1, persisted.result_generation
    assert_equal store.digest_for(store.raw_code), persisted.result_digest
    assert_operator persisted.result_expires_at, :>, persisted.authenticated_at
    assert_nil persisted.result_consumed_at
    assert_nil persisted.base_finalized_at
    assert_nil persisted.browser_session_ref
    assert_nil persisted.authorization_grant_redeemed_at
    assert_not_includes persisted.attributes.values, store.raw_code
    assert_equal issuance.code, store.raw_code
    assert_equal 1, store.options.fetch(:result_generation)
  end

  test "a result can be reissued as a newer generation without overwriting authentication evidence" do
    transaction = issue_authenticated_transaction!
    store = PurposeCaptureStore.new

    first = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, store: store)
    first_digest = transaction.reload.result_digest
    first_authentication_time = transaction.authenticated_at

    second = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction.reload, store: store)
    persisted = transaction.reload

    assert_not_equal first.code, second.code
    assert_equal 2, persisted.result_generation
    assert_not_equal first_digest, persisted.result_digest
    assert_equal first_authentication_time, persisted.authenticated_at
    assert_equal 2, store.options.fetch(:result_generation)
  end

  test "result issuance keeps the durable generation when Valkey delivery fails" do
    transaction = issue_authenticated_transaction!

    assert_raises(Umaxica::Valkey::Unavailable) do
      BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, store: FailingStore.new)
    end

    persisted = transaction.reload

    assert_equal 1, persisted.result_generation
    assert_predicate persisted.result_digest, :present?
    assert_predicate persisted.result_expires_at, :present?
    assert_nil persisted.result_consumed_at
    assert_nil persisted.base_finalized_at
    assert_nil persisted.browser_session_ref
  end

  private

  def issue_transaction!
    OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: "core-app",
        redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris.first,
        code_challenge: "challenge",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
  end

  def issue_authenticated_transaction!
    transaction = issue_transaction!
    OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "app",
      login_challenge: transaction.login_challenge,
      actor: clients(:one),
      session_ref: "session-ref",
      auth_method: "passkey",
      authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
    ).transaction
  end

  class PurposeCaptureStore
    attr_reader :options, :purpose, :raw_code

    def issue!(purpose:, raw_code: nil, **options)
      @purpose = purpose
      @options = options
      @raw_code = raw_code || "opaque-code"
      @raw_code
    end

    def digest_for(purpose:, raw_code:)
      Digest::SHA256.hexdigest("#{purpose}:#{raw_code}")
    end
  end

  class FailingStore
    def issue!(**)
      raise Umaxica::Valkey::Unavailable, "test Valkey delivery failure"
    end
  end
end
