# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAuthAdmissionCoordinatorTest < ActiveSupport::TestCase
  fixtures :clients, :client_tokens

  test "registration and bootstrap admissions retain their distinct authoritative purpose" do
    base_token = client_tokens(:one)
    %w(bootstrap credential_registration credential_change).each do |purpose|
      transaction = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_totp",
        required_aal: "none", allowed_methods: ["totp"], purpose: purpose,
      )
      issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction, base_browser_nonce: "test-browser-nonce", base_token: base_token,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
      _auth_session, raw_sid = prepare_admission_binding_for_consumption!(binding, base_token: base_token)
      payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "app", expected_intent: purpose,
        binding: binding, raw_auth_sid: raw_sid,
      )
      resolved = BaseAuthAdmissionCoordinator.resolve_step_up_admission!(
        payload: payload, surface: "app", expected_intent: purpose,
      )

      assert_equal transaction.id, resolved.id
      assert_equal "#{purpose}_handoff", payload.fetch("purpose")
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseAuthAdmissionCoordinator.resolve_step_up_admission!(
          payload: payload, surface: "app", expected_intent: "step_up",
        )
      end
      ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "#{purpose}_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      )

      assert_equal transaction.transaction_id, ceremony.step_up_ceremony_transaction_ref
      assert_nil ceremony.local_sign_in_flow_ref
      assert_nil ceremony.local_sign_up_flow_ref
    end
  end

  test "step-up admission resolves only its purpose-bound pending transaction" do
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "actor", session_ref: "session", required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"],
    )
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: "test-browser-nonce", base_token: client_tokens(:one),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    _auth_session, raw_sid = prepare_admission_binding_for_consumption!(binding, base_token: client_tokens(:one))
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up",
      binding: binding, raw_auth_sid: raw_sid,
    )
    resolved = BaseAuthAdmissionCoordinator.resolve_step_up_admission!(
      payload: payload, surface: "app", expected_intent: "step_up",
    )

    assert_equal transaction.id, resolved.id
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.resolve_step_up_admission!(
        payload: payload, surface: "com", expected_intent: "step_up",
      )
    end
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.resolve_step_up_admission!(
        payload: payload, surface: "app", expected_intent: "reauthentication",
      )
    end
    transaction.update!(status: "canceled")
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.resolve_step_up_admission!(
        payload: payload, surface: "app", expected_intent: "step_up",
      )
    end
  end

  test "step-up admission is not classified as a local sign-in entry" do
    assert_not BaseAuthAdmissionCoordinator.local_entry_purpose?(
      payload: { "purpose" => "step_up_handoff" }, intent: "step_up",
    )
  end

  test "step-up result reads its concrete ticket without resolving an OIDC transaction" do
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "actor", session_ref: "session", required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"],
    )
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_credential_ref: "key",
      verified_at: ClientStepUpCeremonyTransaction.database_now,
    )
    issuance = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction)

    payload = BaseAuthAdmissionCoordinator.read_result!(
      raw_code: issuance.code, surface: "app", transaction_ref: transaction.transaction_id,
      expected_intent: "step_up",
    )

    assert_equal transaction.transaction_id, payload.fetch("subject_ref")
    assert_equal "step_up_result", payload.fetch("purpose")
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.read_result!(
        raw_code: issuance.code, surface: "app", transaction_ref: transaction.transaction_id,
        expected_intent: "sign_in",
      )
    end
  end

  test "local admission names an existing pending flow without issuing a session" do
    nonce_digest = ClientSignInFlow.digest_nonce("base-browser-nonce")
    issuance = nil
    assert_no_difference("ClientToken.count") do
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: "app", intent: "sign_in", nonce_digest: nonce_digest,
        base_browser_nonce: "test-browser-nonce", base_token: nil,
      )
    end
    assert_instance_of ClientSignInFlow, issuance.transaction
    assert_match(BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN, issuance.reference)
    assert_equal nonce_digest, issuance.transaction.nonce_digest
    assert_nil issuance.transaction.principal_id
    assert_nil issuance.transaction.token_id
    assert_predicate issuance.transaction, :sign_in_primary_pending?
  end

  test "an explicit local restart retires the old binding and preserves the pending flow" do
    first = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", nonce_digest: ClientSignInFlow.digest_nonce("entry-nonce"),
      base_browser_nonce: "test-browser-nonce", base_token: nil,
    )

    second = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", restart_of: first.reference,
      nonce_digest: first.transaction.nonce_digest,
      base_browser_nonce: "test-browser-nonce", base_token: nil,
    )

    assert_not_equal first.reference, second.reference
    assert_equal first.transaction.id, second.transaction.id
    assert_predicate BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app", reference: first.reference,
    ), :retired?
    assert_predicate BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app", reference: second.reference,
    ), :live?
  end

  test "handoff consume is one-shot and bound to surface" do
    transaction = issue_transaction!

    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: "test-browser-nonce", base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    _auth_session, raw_sid = prepare_admission_binding_for_consumption!(binding, base_token: nil)
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_in",
      binding:, raw_auth_sid: raw_sid,
    )

    assert_equal transaction.transaction_id, payload.fetch("subject_ref")
    assert_equal "app", payload.fetch("surface")
    assert_equal "client", payload.fetch("actor_type")

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "app", expected_intent: "sign_in",
        binding:, raw_auth_sid: raw_sid,
      )
    end
  end

  test "local entry consume returns the payload once for the issuing surface" do
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "com", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
    )

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    _auth_session, raw_sid = prepare_admission_binding_for_consumption!(binding, base_token: nil)
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "com", expected_intent: "sign_in",
      binding:, raw_auth_sid: raw_sid,
    )

    assert_equal issuance.transaction.public_id, payload.fetch("subject_ref")
    assert_equal "visitor", payload.fetch("actor_type")
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "com", expected_intent: "sign_in",
        binding:, raw_auth_sid: raw_sid,
      )
    end
  end

  test "local entry consume denies a code issued for another surface" do
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "com", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
    )

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    _auth_session, raw_sid = prepare_admission_binding_for_consumption!(binding, base_token: nil)
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "app", expected_intent: "sign_in",
        binding:, raw_auth_sid: raw_sid,
      )
    end
  end

  test "local entry consume denies a code issued for another intent" do
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "com", intent: "sign_up", base_browser_nonce: "test-browser-nonce", base_token: nil,
    )

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    _auth_session, raw_sid = prepare_admission_binding_for_consumption!(binding, base_token: nil)
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "com", expected_intent: "sign_in",
        binding:, raw_auth_sid: raw_sid,
      )
    end
  end

  test "local entry consume denies an unknown code" do
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: SecureRandom.uuid, surface: "com", expected_intent: "sign_in",
        binding: ClientAuthAdmissionBinding.new, raw_auth_sid: "missing",
      )
    end
  end

  test "local entry consume rejects an unsupported intent" do
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "com", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    _auth_session, raw_sid = prepare_admission_binding_for_consumption!(binding, base_token: nil)
    assert_raises(ArgumentError) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "com", expected_intent: "withdrawal",
        binding:, raw_auth_sid: raw_sid,
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
    assert_equal(
      Valkey::AuthState::OpaqueAdmissionStore.digest_for(purpose: store.purpose, raw_code: store.raw_code),
      persisted.result_digest,
    )
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
  end

  class FailingStore
    def issue!(**)
      raise Umaxica::Valkey::Unavailable, "test Valkey delivery failure"
    end
  end
end
