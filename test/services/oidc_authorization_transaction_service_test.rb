# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcAuthorizationTransactionCoordinatorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = clients(:one)
    @params = {
      response_type: "code",
      client_id: "core-app",
      redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end

  test "issue creates a pending transaction without a resume URL" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(surface: "app", intent: "sign_in", params: @params)

    assert_predicate issuance.transaction, :persisted?
    assert_equal "pending", issuance.transaction.status
    assert_equal "app", issuance.transaction.surface
    assert_equal "sign_in", issuance.transaction.intent
    assert_not_respond_to issuance, :resume_url
    assert_not_respond_to issuance.transaction, :acme_resume_url
  end

  test "same-browser exact OIDC initiation retry reuses its parent and fixed admission deadline in every realm" do
    [%w(app core-app client), %w(com core-com visitor), %w(org core-org operator)].each do |surface, client_id, realm|
      parameters = @params.merge(
        client_id: client_id,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
        state: SecureRandom.urlsafe_base64(32), nonce: SecureRandom.urlsafe_base64(32),
      )
      nonce = SecureRandom.urlsafe_base64(32)
      first = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
        surface:, intent: "authentication", params: parameters, base_browser_nonce: nonce, base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: first.handoff.reference)
      expiry = binding.expires_at
      second = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
        surface:, intent: "authentication", params: parameters, base_browser_nonce: nonce, base_token: nil,
      )

      assert_equal first.transaction.id, second.transaction.id, surface
      assert_equal first.handoff.reference, second.handoff.reference, surface
      assert_equal expiry, binding.reload.expires_at
      assert_equal 1, first.transaction.class.where(state: parameters.fetch(:state)).count
      binding.update_columns(expires_at: binding.class.database_now - 1.second)
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: first.transaction, base_browser_nonce: nonce, base_token: nil,
        )
      end

      assert_nil binding.reload.retired_at, "ordinary retry cannot silently restart an expired admission"
      [[SecureRandom.urlsafe_base64(32), parameters],
       [nonce, parameters.merge(nonce: "different")],].each do |proof, input|
        counts = [first.transaction.class.count, binding.class.count]
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
            surface:, intent: "authentication", params: input, base_browser_nonce: proof, base_token: nil,
            restart_of: first.handoff.reference,
          )
        end

        assert_equal counts, [first.transaction.class.count, binding.class.count]
        assert_nil binding.reload.retired_at
      end
      restarted = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
        surface:, intent: "authentication", params: parameters, base_browser_nonce: nonce, base_token: nil,
        restart_of: first.handoff.reference,
      )

      assert_equal first.transaction.id, restarted.transaction.id
      assert_equal first.transaction.expires_at, restarted.transaction.expires_at
      assert_not_equal first.handoff.reference, restarted.handoff.reference
      assert_predicate binding.reload, :retired?
    end
  end

  test "default issue and state transitions use the writer database clock" do
    issue_time = Time.utc(2026, 1, 2, 3, 4, 5)
    authentication_time = Time.utc(2026, 1, 2, 3, 4, 6)
    consume_time = Time.utc(2026, 1, 2, 3, 4, 7)

    issuance =
      ClientOidcAuthorizationTransaction.stub(:database_now, issue_time) do
        OidcAuthorizationTransactionCoordinator.issue!(surface: "app", intent: "authentication", params: @params)
      end

    assert_in_delta issue_time.to_f, issuance.transaction.created_at.to_f, 0.001
    assert_in_delta issue_time.to_f, issuance.transaction.updated_at.to_f, 0.001

    result =
      ClientOidcAuthorizationTransaction.stub(:database_now, authentication_time) do
        OidcAuthorizationTransactionCoordinator.register_result!(
          surface: "app",
          login_challenge: issuance.transaction.login_challenge,
          actor: @client,
          session_ref: "session-1",
          auth_method: "passkey",
          authentication_event_at: authentication_time,
        )
      end

    assert_in_delta authentication_time.to_f, result.transaction.updated_at.to_f, 0.001
    assert_in_delta authentication_time.to_f, result.transaction.authenticated_at.to_f, 0.001

    consumed =
      ClientOidcAuthorizationTransaction.stub(:database_now, consume_time) do
        OidcAuthorizationTransactionCoordinator.consume!(
          surface: "app",
          login_challenge: issuance.transaction.login_challenge,
        )
      end

    assert_in_delta consume_time.to_f, consumed.updated_at.to_f, 0.001
    assert_in_delta consume_time.to_f, consumed.consumed_at.to_f, 0.001
  end

  test "admission refuses an expired parent before burning opaque entry state" do
    issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
      surface: "app", intent: "authentication", params: @params,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app",
      reference: issuance.handoff.reference,
    )
    _session, raw_sid =
      begin
        admission_binding = binding
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_binding.class.auth_admission_surface_name,
            entry_ref: admission_binding.entry_ref,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          ),
        )
        [admission_session, admission_raw_sid]
      end
    store = Valkey::AuthState::OpaqueAdmissionStore.new
    payload = store.read_reference!(reference: binding.entry_ref)
    issuance.transaction.update!(login_challenge_expires_at: issuance.transaction.class.database_now - 1.second)

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: binding.entry_ref, surface: "app", expected_intent: "sign_in", binding:, raw_auth_sid: raw_sid,
      )
    end

    assert_equal payload, store.read_reference!(reference: binding.entry_ref)
    assert_nil binding.reload.redeemed_at
  end

  test "admission rechecks root expiry after Base confirmation without burning opaque entry state" do
    token = ClientToken.create!(user: @client, created_at: ClientToken.database_now - 1.minute)
    issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
      surface: "app", intent: "authentication", params: @params,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app", reference: issuance.handoff.reference,
    )
    _session, raw_sid =
      begin
        admission_binding = binding
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: token,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_binding.class.auth_admission_surface_name,
            entry_ref: admission_binding.entry_ref,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          ),
        )
        [admission_session, admission_raw_sid]
      end
    store = Valkey::AuthState::OpaqueAdmissionStore.new
    payload = store.read_reference!(reference: binding.entry_ref)
    token.update!(discard_at: token.class.database_now - 1.second)

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: binding.entry_ref, surface: "app", expected_intent: "sign_in", binding:, raw_auth_sid: raw_sid,
      )
    end

    assert_equal payload, store.read_reference!(reference: binding.entry_ref)
    assert_nil binding.reload.redeemed_at
  end

  test "admission refuses a revoked root device before burning opaque entry state" do
    token = ClientToken.create!(user: @client)
    issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
      surface: "app", intent: "authentication", params: @params,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app", reference: issuance.handoff.reference,
    )
    _session, raw_sid =
      begin
        admission_binding = binding
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: token,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_binding.class.auth_admission_surface_name,
            entry_ref: admission_binding.entry_ref,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          ),
        )
        [admission_session, admission_raw_sid]
      end
    store = Valkey::AuthState::OpaqueAdmissionStore.new
    payload = store.read_reference!(reference: binding.entry_ref)
    token.device_session.revoke!

    assert_predicate token.reload, :currently_usable?, "a live token alone cannot restore its revoked device"
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: binding.entry_ref, surface: "app", expected_intent: "sign_in", binding:, raw_auth_sid: raw_sid,
      )
    end

    assert_equal payload, store.read_reference!(reference: binding.entry_ref)
    assert_nil binding.reload.redeemed_at
  end

  test "register_result marks the transaction authenticated and consume makes it one time" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(surface: "app", intent: "sign_in", params: @params)

    result =
      OidcAuthorizationTransactionCoordinator.register_result!(
        surface: "app",
        login_challenge: issuance.transaction.login_challenge,
        actor: @client,
        session_ref: "session-1",
        auth_method: "passkey",
        authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
      )

    assert_predicate result.transaction, :authenticated?
    assert_equal @client.public_id, result.transaction.actor_ref

    consumed = OidcAuthorizationTransactionCoordinator.consume!(
      surface: "app",
      login_challenge: issuance.transaction.login_challenge,
    )

    assert_predicate consumed, :consumed?

    assert_raises(ArgumentError) do
      OidcAuthorizationTransactionCoordinator.consume!(
        surface: "app",
        login_challenge: issuance.transaction.login_challenge,
      )
    end
  end

  test "model_for raises on unsupported surface" do
    assert_raises(ArgumentError, match: /unsupported OIDC authorization surface/) do
      OidcAuthorizationTransactionCoordinator.model_for("unsupported")
    end
  end

  test "register_result refuses to invent an authentication event time" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(surface: "app", intent: "sign_in", params: @params)

    error =
      assert_raises(ArgumentError) do
        OidcAuthorizationTransactionCoordinator.register_result!(
          surface: "app",
          login_challenge: issuance.transaction.login_challenge,
          actor: @client,
          session_ref: "session-1",
          auth_method: "passkey",
        )
      end

    assert_equal "authentication event time is required", error.message
    assert_nil issuance.transaction.reload.authenticated_at
  end

  test "expired login challenge is rejected when registering ceremony result" do
    issuance =
      OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app",
        intent: "sign_in",
        params: @params,
        login_challenge_ttl: 1.second,
        now: Time.current,
      )

    error =
      assert_raises(ArgumentError) do
        OidcAuthorizationTransactionCoordinator.register_result!(
          surface: "app",
          login_challenge: issuance.transaction.login_challenge,
          actor: @client,
          session_ref: "session-1",
          auth_method: "passkey",
          authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
          now: issuance.transaction.login_challenge_expires_at + 1.second,
        )
      end

    assert_equal "authorization transaction expired", error.message
  end

  test "authorization grant redemption is durable and only succeeds once" do
    transaction = issue_authenticated_transaction!
    transaction.finalize_base! do |_locked, _now|
      { status: :success, browser_session_ref: "browser-session-a" }
    end

    first = transaction.claim_authorization_grant!
    second = transaction.reload.claim_authorization_grant!

    assert first
    assert_not second
    assert_predicate transaction.reload.authorization_grant_redeemed_at, :present?
  end

  test "base finalization records one browser session reference without changing actor evidence" do
    transaction = issue_authenticated_transaction!
    authentication_time = transaction.authenticated_at

    first =
      transaction.finalize_base! do |_locked, _now|
        { status: :success, browser_session_ref: "browser-session-a" }
      end
    second =
      transaction.reload.finalize_base! do |_locked, _now|
        { status: :success, browser_session_ref: "browser-session-b" }
      end
    persisted = transaction.reload

    assert_equal :success, first.fetch(:status)
    assert_equal :success, second.fetch(:status)
    assert_equal "browser-session-a", persisted.browser_session_ref
    assert_equal authentication_time, persisted.authenticated_at
    assert_predicate persisted.base_finalized_at, :present?
    assert_predicate persisted.result_consumed_at, :present?
    assert_predicate persisted, :consumed?
  end

  test "base finalization rejects a result from an older generation" do
    transaction = issue_authenticated_transaction!
    now = Time.current
    transaction.prepare_result_delivery!(result_digest: "a" * 64, now: now)
    transaction.prepare_result_delivery!(result_digest: "b" * 64, now: now)

    error =
      assert_raises(ArgumentError) do
        transaction.finalize_base!(result_generation: 1) do
          flunk("a stale result must not execute Base finalization")
        end
      end

    assert_equal "authorization result generation is stale", error.message
    assert_nil transaction.reload.base_finalized_at
    assert_nil transaction.reload.browser_session_ref
  end

  private

  def issue_authenticated_transaction!
    transaction =
      OidcAuthorizationTransactionCoordinator.issue!(surface: "app", intent: "sign_in", params: @params).transaction

    OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "app",
      login_challenge: transaction.login_challenge,
      actor: @client,
      session_ref: "session-1",
      auth_method: "passkey",
      authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
    ).transaction
  end
end
