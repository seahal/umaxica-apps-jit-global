# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAuthAdmissionCoordinatorTest < ActiveSupport::TestCase
  fixtures :clients, :client_tokens

  test "expired binding restart preserves its live parent and browser ownership in every realm" do
    %w(app com org).each do |surface|
      browser_nonce = SecureRandom.urlsafe_base64(32)
      first = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: browser_nonce, base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: surface, reference: first.reference)
      parent_deadline = first.transaction.expires_at
      # Move only the admission deadline; the original parent retains its authorized lifetime.
      binding.update_columns(expires_at: binding.class.database_now - 1.second)
      successor = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: first.transaction, base_browser_nonce: browser_nonce, base_token: nil,
        restart_of: first.reference,
      )

      assert_equal first.transaction.id, successor.transaction.id
      assert_not_equal first.reference, successor.reference
      assert_predicate binding.reload, :retired?
      replacement = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: surface, reference: successor.reference,
      )
      # WU-06: the parent is never shortened and reaches at least the replacement's curfew.
      assert_equal [parent_deadline, replacement.curfew_at].max, successor.transaction.reload.expires_at

      assert_predicate replacement, :live?
      assert_operator replacement.expires_at, :<=, parent_deadline
    end
  end

  test "handoff retry refuses another browser nonce without adopting its existing parent in every realm" do
    [
      %w(app core-app-jp client),
      %w(com core-com-jp visitor),
      %w(org core-org-jp operator),
    ].each do |surface, client_id, realm|
      transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface, intent: "sign_in", params: {
          response_type: "code",
          client_id: client_id,
          redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          scope: "openid",
          state: SecureRandom.urlsafe_base64(32),
          nonce: SecureRandom.urlsafe_base64(32),
        },
      ).transaction
      nonce = SecureRandom.urlsafe_base64(32)
      first = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction, base_browser_nonce: nonce, base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: surface, reference: first.reference)
      deadline = binding.expires_at
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
        )
      end

      assert_nil binding.reload.retired_at
      assert_nil binding.redeemed_at
      same_browser = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction, base_browser_nonce: nonce, base_token: nil,
      )

      assert_equal first.reference, same_browser.reference
      assert_equal deadline, binding.reload.expires_at
    end
  end

  test "registration and bootstrap admissions retain their distinct authoritative purpose" do
    base_token = client_tokens(:one)
    %w(bootstrap credential_registration credential_change).each do |purpose|
      transaction = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: base_token.actor_record.public_id,
        session_ref: base_token.public_id, required_scope: "settings_totp",
        required_aal: "none", allowed_methods: ["totp"], purpose: purpose,
      )
      issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction,
        base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        base_token: base_token,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
      _auth_session, raw_sid =
        begin
          admission_binding = binding
          admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
          admission_binding.attach_auth_session!(
            auth_session: admission_session,
            confirmation_ref: SecureRandom.uuid,
          )
          admission_binding.confirm_base!(
            base_token: base_token,
            browser_digest: AuthAdmissionBinding.browser_digest(
              surface: admission_binding.class.auth_admission_surface_name,
              entry_ref: admission_binding.entry_ref,
              nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
            ),
          )
          [admission_session, admission_raw_sid]
        end
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
    end
  end

  test "step-up admission refuses substituted actor session and token binding before consuming its entry" do
    token = client_tokens(:one)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: token.user.public_id, session_ref: token.public_id,
      required_scope: "settings_birthdate", required_aal: "none", allowed_methods: ["passkey"],
    )
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction:, base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    _auth_session, raw_sid =
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
    original = store.read_reference!(reference: issuance.reference)
    { actor_ref: clients(:two).public_id,
      session_ref: "foreign-session",
      token_binding: "foreign-token",
      require_session_binding: false, }.each do |field, replacement|
      authorized = transaction[field]
      transaction.update_columns(field => replacement)

      assert_raises(BaseAuthAdmissionCoordinator::Denied, field.to_s) do
        BaseAuthAdmissionCoordinator.consume_entry_reference!(
          reference: issuance.reference, surface: "app", expected_intent: "step_up",
          binding:, raw_auth_sid: raw_sid,
        )
      end

      assert_equal original, store.read_reference!(reference: issuance.reference)
      assert_nil binding.reload.redeemed_at
      transaction.update_columns(field => authorized)
    end
  end

  test "step-up admission resolves only its purpose-bound pending transaction" do
    token = client_tokens(:one)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: token.user.public_id, session_ref: token.public_id, required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"],
    )
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: client_tokens(:one),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    _auth_session, raw_sid =
      begin
        admission_binding = binding
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: client_tokens(:one),
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_binding.class.auth_admission_surface_name,
            entry_ref: admission_binding.entry_ref,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          ),
        )
        [admission_session, admission_raw_sid]
      end
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

  test "redeemed step-up result retains its original browser binding after admission expiry" do
    token = client_tokens(:one)
    nonce = SecureRandom.urlsafe_base64(32)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: token.user.public_id, session_ref: token.public_id, required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"],
    )
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction:, base_browser_nonce: nonce, base_token: token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    auth, raw_sid =
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
            nonce: nonce,
          ),
        )
        [admission_session, admission_raw_sid]
      end
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: auth, admitted_auth_session: admitted)
    binding.update_columns(expires_at: binding.class.database_now - 1.second)

    assert_equal binding, BaseAuthAdmissionCoordinator.validate_result_browser_binding!(
      transaction:, surface: "app", base_browser_nonce: nonce, base_token: token,
    )
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.validate_result_browser_binding!(
        transaction:, surface: "app", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: token,
      )
    end

    assert_predicate binding.reload, :redeemed?
    assert_nil token.reload.last_step_up_at
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

  test "handoff consume is one-shot and bound to surface" do
    transaction = issue_transaction!

    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    _auth_session, raw_sid =
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

  test "OIDC intent substitution does not consume the original sign-in admission" do
    transaction = issue_transaction!
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction:, base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    _auth_session, raw_sid =
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

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "app", expected_intent: "sign_up",
        binding:, raw_auth_sid: raw_sid,
      )
    end
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_in",
      binding:, raw_auth_sid: raw_sid,
    )

    assert_equal transaction.transaction_id, payload.fetch("subject_ref")
    assert_nil binding.reload.redeemed_at
  end

  test "entry consume returns the payload once for the issuing surface" do
    issuance = OidcTestEntry.issue!(
      surface: "com",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    _auth_session, raw_sid =
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
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "com", expected_intent: "sign_in",
      binding:, raw_auth_sid: raw_sid,
    )

    assert_equal issuance.transaction.transaction_id, payload.fetch("subject_ref")
    assert_equal "visitor", payload.fetch("actor_type")
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "com", expected_intent: "sign_in",
        binding:, raw_auth_sid: raw_sid,
      )
    end
  end

  test "local entry consume denies a code issued for another surface" do
    issuance = OidcTestEntry.issue!(
      surface: "com",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    _auth_session, raw_sid =
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
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "app", expected_intent: "sign_in",
        binding:, raw_auth_sid: raw_sid,
      )
    end
  end

  test "local entry consume denies a code issued for another intent" do
    issuance = OidcTestEntry.issue!(
      surface: "com",
      intent: "sign_up",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    _auth_session, raw_sid =
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
    issuance = OidcTestEntry.issue!(
      surface: "com",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    _auth_session, raw_sid =
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
        client_id: "core-app-jp",
        redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
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
  public

  test "social signup acceptance requires the redeemed browser parent and exact provider evidence" do
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = OidcTestEntry.issue!(
      surface: "app", intent: "sign_up", base_browser_nonce: nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    pending, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: pending, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(surface: "app", entry_ref: binding.entry_ref, nonce:),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "app", expected_intent: "sign_up", binding:, raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: issuance.transaction.transaction_id,
    )
    binding.redeem!(auth_session: pending, admitted_auth_session: admitted)
    record = ClientAuthCeremonySession.find(binding.reload.admitted_auth_ceremony_session_id)
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.validate_social_result_browser_binding!(
        reference: binding.entry_ref, surface: "app", provider: "google", base_browser_nonce: nonce, base_token: nil,
      )
    end
    record.record_authentication_evidence!(method: "google")

    assert_equal binding.id, BaseAuthAdmissionCoordinator.validate_social_result_browser_binding!(
      reference: binding.entry_ref, surface: "app", provider: "google", base_browser_nonce: nonce, base_token: nil,
    ).id
    [nil, "", " ", [], {}, SecureRandom.urlsafe_base64(32)].each do |other_nonce|
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseAuthAdmissionCoordinator.validate_social_result_browser_binding!(
          reference: binding.entry_ref,
          surface: "app",
          provider: "google",
          base_browser_nonce: other_nonce,
          base_token: nil,
        )
      end
    end
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.validate_social_result_browser_binding!(
        reference: binding.entry_ref, surface: "app", provider: "apple", base_browser_nonce: nonce, base_token: nil,
      )
    end
    deadline = binding.expires_at
    [-1, 0, 1].each do |microseconds|
      ClientAuthAdmissionBinding.stub(:database_now, deadline + Rational(microseconds, 1_000_000)) do
        if microseconds.negative?
          assert_equal binding.id, BaseAuthAdmissionCoordinator.validate_social_result_browser_binding!(
            reference: binding.entry_ref,
            surface: "app",
            provider: "google",
            base_browser_nonce: nonce,
            base_token: nil,
          ).id
        else
          assert_raises(BaseAuthAdmissionCoordinator::Denied) do
            BaseAuthAdmissionCoordinator.validate_social_result_browser_binding!(
              reference: binding.entry_ref,
              surface: "app",
              provider: "google",
              base_browser_nonce: nonce,
              base_token: nil,
            )
          end
        end
      end
    end
    record.complete!
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.validate_social_result_browser_binding!(
        reference: binding.entry_ref, surface: "app", provider: "google", base_browser_nonce: nonce, base_token: nil,
      )
    end
    assert_not ClientSocialCeremonyTransaction.exists?(session_ref: binding.entry_ref)
  end
end
