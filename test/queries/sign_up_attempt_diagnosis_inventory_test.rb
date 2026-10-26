# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpAttemptDiagnosisInventoryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @base_browser_nonce = SecureRandom.urlsafe_base64(32)
    client_id = "core-app-jp"
    oidc_client = OidcClientRegistry.find!(client_id)
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_up",
      params: {
        client_id:,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: oidc_client.redirect_uris_by_realm.fetch("client").first,
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        prompt: "create",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction:,
      base_browser_nonce: @base_browser_nonce,
      base_token: nil,
    )
    @entry_reference = issuance.reference
    @entry_reference_digest = Valkey::AuthState::OpaqueAdmissionStore.reference_digest(
      reference: @entry_reference,
    )
    @binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app",
      reference: @entry_reference,
    )
    auth_session_class = @binding.class.auth_admission_session_class
    attached_session, raw_auth_sid = auth_session_class.issue!
    @binding.attach_auth_session!(auth_session: attached_session, confirmation_ref: SecureRandom.uuid)
    @binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app",
        entry_ref: @entry_reference,
        nonce: @base_browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: @entry_reference,
      surface: "app",
      expected_intent: "sign_up",
      binding: @binding,
      raw_auth_sid:,
    )
    admitted_session, = auth_session_class.rotate_and_admit!(
      admission_purpose: "authentication_handoff",
      previous_raw_sid: raw_auth_sid,
      authorization_transaction_ref: transaction.transaction_id,
    )
    @binding.redeem!(auth_session: attached_session, admitted_auth_session: admitted_session)

    flow_now = ClientSignUpFlow.database_now
    @flow = ClientSignUpFlow.create!(
      auth_admission_binding: @binding,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: flow_now,
      expires_at: flow_now + 15.minutes,
      entry_method: "email",
    )
  end

  test "an open attempt without a principal is in progress and reports its OP references" do
    report = SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: @flow.public_id)

    assert_equal "in_progress_without_principal", report.fetch(:classification)
    assert_equal @flow.auth_admission_binding_id, report.dig(:op, :binding, :id)
    assert_equal "sign_up", report.dig(:op, :binding, :entry_intent)
    assert_equal "pending", report.dig(:op, :oidc_authorization, :status)
    assert_equal @binding.admitted_auth_ceremony_session_id,
                 report.dig(:op, :ceremony_sessions).fetch(:admitted).fetch(:id)
    assert_predicate report.dig(:op, :read_at), :present?
    assert_equal @flow.public_id,
                 report.dig(:correlations, :chronicle, :structured_log_search).fetch(:flow_public_id)
  end

  test "a committed principal without its graph on an open Flow is classified as such" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @flow.update!(principal_id: client.id)
    report = SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: @flow.public_id)

    assert_equal "principal_committed_graph_missing_flow_open", report.fetch(:classification)
    assert_equal client.id, report.dig(:principal, :actor, :id)
    assert_equal client.access_enabled?, report.dig(:principal, :actor, :access_enabled)
    assert_not report.dig(:graph, :identity)
  end

  test "a completed Flow without a principal is the social partial commit" do
    @flow.update!(
      status_id: ClientSignUpFlowStatus::COMPLETED,
      state: "COMPLETED",
      step: "completed",
      completed_at: Time.current,
    )
    report = SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: @flow.public_id)

    assert_equal "completed_without_principal", report.fetch(:classification)
  end

  test "an unknown well-formed Flow id is reported as not found" do
    report = SignUpAttemptDiagnosisInventory.call(surface: :com, flow_public_id: PublicId.generate)

    assert_equal "flow_not_found", report.fetch(:classification)
  end

  test "unknown entry, principal, and social digests are explicitly not found" do
    entry_report = SignUpAttemptDiagnosisInventory.call(
      surface: :app,
      entry_reference_digest: Digest::SHA256.hexdigest("reference:missing-entry"),
    )
    principal_report = SignUpAttemptDiagnosisInventory.call(
      surface: :app,
      principal_public_id: PublicId.generate,
    )
    subject_digest = IdentitySocialCeremonyContract.provider_subject_digest(
      provider: "google",
      subject: "missing-social-subject",
    )
    social_report = SignUpAttemptDiagnosisInventory.call(
      surface: :app,
      provider: "google",
      subject_digest:,
    )

    assert_equal "flow_not_found", entry_report.fetch(:classification)
    assert_equal "flow_not_found", principal_report.fetch(:classification)
    assert_equal "flow_not_found", social_report.fetch(:classification)
  end

  test "the report carries no contact value, subject, nonce digest or entry reference" do
    address = "diagnosis-#{SecureRandom.hex(4)}@example.com"
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    ClientEmail.create!(user_id: client.id, address:)
    @flow.update!(principal_id: client.id)
    report = SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: @flow.public_id)
    text = report.to_json

    assert_not_includes text, address
    assert_not_includes text, @flow.nonce_digest
    assert_not_includes text, @entry_reference
    assert_not_includes text, @binding.base_browser_digest
  end

  test "an entry reference digest resolves its Flow without returning the raw reference" do
    report = SignUpAttemptDiagnosisInventory.call(
      surface: :app,
      entry_reference_digest: @entry_reference_digest,
    )

    assert_equal @flow.public_id, report.dig(:op, :flow, :public_id)
    assert_not_includes report.to_json, @entry_reference
  end

  test "a principal public id resolves its Flow" do
    client = Client.create!(
      public_id: PublicId.generate,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    @flow.update!(principal_id: client.id)

    report = SignUpAttemptDiagnosisInventory.call(surface: :app, principal_public_id: client.public_id)

    assert_equal @flow.public_id, report.dig(:op, :flow, :public_id)
    assert_equal client.id, report.dig(:principal, :actor, :id)
  end

  test "a provider subject digest resolves its social Candidate without returning the subject" do
    subject = "diagnosis-social-#{SecureRandom.hex(8)}"
    callback_result = ExternalAuthentication::CallbackResult.verified(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google",
        subject:,
        issuer: "https://accounts.google.com",
        audience: "diagnosis-client-id",
        verified_at: Time.current,
        verification_authority: "google-provider-contract",
      ),
      credential_candidate: nil,
    )
    candidate = IdentitySocialCeremonyCandidateStore.store!(
      surface: "app",
      actor_ref: @flow.public_id,
      session_ref: "diagnosis-session-#{SecureRandom.hex(8)}",
      transaction_id: "diagnosis-transaction-#{SecureRandom.hex(8)}",
      operation: "signup",
      provider: "google",
      callback_result:,
      expires_at: 5.minutes.from_now,
    )
    subject_digest = IdentitySocialCeremonyContract.provider_subject_digest(provider: "google", subject:)

    report = SignUpAttemptDiagnosisInventory.call(
      surface: :app,
      provider: "google",
      subject_digest:,
    )

    assert_equal @flow.public_id, report.dig(:op, :flow, :public_id)
    candidate_id = IdentitySocialCeremonyCandidate.find_by!(ref: candidate.ref).id

    assert_equal candidate_id, report.dig(:op, :social_candidates).first.fetch(:id)
    assert_not_includes report.to_json, subject
    assert_not_includes report.to_json, subject_digest
    assert_not_includes report.to_json, candidate.ref
  end

  test "audit correlations return event identifiers and names without contact references" do
    contact_reference = PublicId.generate
    event_uuid = SecureRandom.uuid
    ClientContactAuditOutbox.create!(
      event_uuid:,
      contact_kind: "email",
      event_name: "finalized",
      owner_ref: PublicId.generate,
      contact_ref: contact_reference,
      operation_ref: @flow.public_id,
      actor_ref: @flow.public_id,
      occurred_at: ClientContactAuditOutbox.database_now,
    )

    report = SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: @flow.public_id)
    outbox =
      report.dig(:correlations, :audit, :outboxes)
        .find { |entry| entry.fetch(:name) == "ClientContactAuditOutbox" }

    assert_equal event_uuid, outbox.fetch(:events).first.fetch(:event_id)
    assert_equal "finalized", outbox.fetch(:events).first.fetch(:event_name)
    assert_not_includes report.to_json, contact_reference
  end

  test "a principal lookup returns every matching attempt" do
    client = Client.create!(
      public_id: PublicId.generate,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    @flow.update!(principal_id: client.id)

    base_browser_nonce = SecureRandom.urlsafe_base64(32)
    client_id = "core-app-jp"
    oidc_client = OidcClientRegistry.find!(client_id)
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_up",
      params: {
        client_id:,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: oidc_client.redirect_uris_by_realm.fetch("client").first,
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        prompt: "create",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction:,
      base_browser_nonce:,
      base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    auth_session_class = binding.class.auth_admission_session_class
    attached_session, raw_auth_sid = auth_session_class.issue!
    binding.attach_auth_session!(auth_session: attached_session, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app",
        entry_ref: issuance.reference,
        nonce: base_browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference,
      surface: "app",
      expected_intent: "sign_up",
      binding:,
      raw_auth_sid:,
    )
    admitted_session, = auth_session_class.rotate_and_admit!(
      admission_purpose: "authentication_handoff",
      previous_raw_sid: raw_auth_sid,
      authorization_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached_session, admitted_auth_session: admitted_session)
    flow_now = ClientSignUpFlow.database_now
    second_flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding,
      principal_id: client.id,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: flow_now,
      expires_at: flow_now + 15.minutes,
      entry_method: "email",
    )

    report = SignUpAttemptDiagnosisInventory.call(surface: :app, principal_public_id: client.public_id)

    assert_equal "multiple_attempts_found", report.fetch(:classification)
    assert_equal [@flow.public_id, second_flow.public_id].sort,
                 report.fetch(:attempts).map { |attempt| attempt.dig(:op, :flow, :public_id) }.sort
  end

  test "a COM attempt is not returned by APP lookup" do
    base_browser_nonce = SecureRandom.urlsafe_base64(32)
    client_id = "core-com-jp"
    oidc_client = OidcClientRegistry.find!(client_id)
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com",
      intent: "sign_up",
      params: {
        client_id:,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: oidc_client.redirect_uris_by_realm.fetch("visitor").first,
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        prompt: "create",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction:,
      base_browser_nonce:,
      base_token: nil,
    )
    com_entry_reference_digest = Valkey::AuthState::OpaqueAdmissionStore.reference_digest(
      reference: issuance.reference,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    auth_session_class = binding.class.auth_admission_session_class
    attached_session, raw_auth_sid = auth_session_class.issue!
    binding.attach_auth_session!(auth_session: attached_session, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "com",
        entry_ref: issuance.reference,
        nonce: base_browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference,
      surface: "com",
      expected_intent: "sign_up",
      binding:,
      raw_auth_sid:,
    )
    admitted_session, = auth_session_class.rotate_and_admit!(
      admission_purpose: "authentication_handoff",
      previous_raw_sid: raw_auth_sid,
      authorization_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached_session, admitted_auth_session: admitted_session)
    visitor = Visitor.create!(
      public_id: PublicId.generate,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow_now = VisitorSignUpFlow.database_now
    com_flow = VisitorSignUpFlow.create!(
      auth_admission_binding: binding,
      principal_id: visitor.id,
      status_id: VisitorSignUpFlowStatus::STARTED,
      step: "start",
      nonce_digest: VisitorSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: flow_now,
      expires_at: flow_now + 15.minutes,
      entry_method: "email",
    )

    report = SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: com_flow.public_id)

    assert_equal "flow_not_found", report.fetch(:classification)
    assert_equal "flow_not_found",
                 SignUpAttemptDiagnosisInventory.call(
                   surface: :app,
                   entry_reference_digest: com_entry_reference_digest,
                 ).fetch(:classification)
    assert_equal "flow_not_found",
                 SignUpAttemptDiagnosisInventory.call(
                   surface: :app,
                   principal_public_id: visitor.public_id,
                 ).fetch(:classification)
    assert_equal "flow_not_found",
                 SignUpAttemptDiagnosisInventory.call(
                   surface: :com,
                   provider: "google",
                   subject_digest: "a" * 64,
                 ).fetch(:classification)
  end

  test "malformed, empty, nil, and ambiguous selectors are refused" do
    assert_raises(ArgumentError) { SignUpAttemptDiagnosisInventory.call(surface: :app) }
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: nil)
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: "")
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: "not-a-public-id")
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, entry_reference_digest: @entry_reference)
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, entry_reference_digest: nil)
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, principal_public_id: "contact@example.com")
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, provider: "google", subject_digest: "raw-subject")
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, provider: "unsupported", subject_digest: "a" * 64)
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, provider: "google")
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, provider: "google", subject_digest: nil)
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :app, provider: "google", subject_digest: "")
    end
    assert_raises(ArgumentError) do
      SignUpAttemptDiagnosisInventory.call(surface: :org, flow_public_id: @flow.public_id)
    end
  end

  test "a caller inside a writing role scope is refused" do
    ActiveRecord::Base.connected_to(role: :writing) do
      assert_raises(SignUpAttemptDiagnosisInventory::WritingRoleRefused) do
        SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: @flow.public_id)
      end
    end
  end
end
