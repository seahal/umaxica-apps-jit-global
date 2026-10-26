# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpStuckRegistrationReportQueryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "finds a pending principal and contact after their Flow is gone without returning contact data" do
    address = "stuck-app-#{SecureRandom.hex(6)}@example.com"
    client = Client.create!(
      public_id: PublicId.generate,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    email = ClientEmail.create!(
      user_id: client.id,
      address:,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    registered_client = Client.create!(
      public_id: PublicId.generate,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
    )
    ClientEmail.create!(
      user_id: registered_client.id,
      address: "registered-pending-#{SecureRandom.hex(6)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    principal_without_contact = Client.create!(
      public_id: PublicId.generate,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )

    report = SignUpStuckRegistrationReportQuery.call(surface: :app)
    stuck = report.find { |row| row.fetch(:principal_public_id) == client.public_id }
    principal_only =
      report.find do |row|
        row.fetch(:principal_public_id) == principal_without_contact.public_id
      end

    assert_equal 2, report.length
    assert_equal "app", stuck.fetch(:surface)
    assert_equal "flow_missing", stuck.fetch(:case)
    assert_equal client.public_id, stuck.fetch(:principal_public_id)
    assert_equal email.public_id, stuck.fetch(:contact_public_id)
    assert_nil stuck.fetch(:flow_public_id)
    assert_nil stuck.fetch(:cleanup_attempts_count)
    assert_not report.any? { |row| row.fetch(:principal_public_id) == registered_client.public_id }
    assert_nil principal_only.fetch(:contact_public_id)
    assert_nil principal_only.fetch(:flow_public_id)
    assert_equal %i(
      case cleanup_attempts_count contact_public_id flow_public_id principal_public_id surface
    ),
                 stuck.keys.sort
    assert_not_includes report.to_json, address
  end

  test "keeps APP and COM orphan records within their own surface" do
    app_client = Client.create!(
      public_id: PublicId.generate,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    app_email = ClientEmail.create!(
      user_id: app_client.id,
      address: "app-isolated-#{SecureRandom.hex(6)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    app_telephone = ClientTelephone.create!(
      user: app_client,
      raw_number: "+12025550114",
      confirm_policy: true,
      confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    com_visitor = Visitor.create!(
      public_id: PublicId.generate,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    com_email = VisitorEmail.create!(
      visitor_id: com_visitor.id,
      address: "com-isolated-#{SecureRandom.hex(6)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    com_telephone = VisitorTelephone.create!(
      visitor: com_visitor,
      raw_number: "+12025550115",
      confirm_policy: true,
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )

    app_report = SignUpStuckRegistrationReportQuery.call(surface: :app)
    com_report = SignUpStuckRegistrationReportQuery.call(surface: :com)

    assert_includes app_report.map { |row| row.fetch(:contact_public_id) }, app_email.public_id
    assert_includes app_report.map { |row| row.fetch(:contact_public_id) }, app_telephone.public_id
    assert_not_includes app_report.map { |row| row.fetch(:principal_public_id) }, com_visitor.public_id
    assert_includes com_report.map { |row| row.fetch(:contact_public_id) }, com_email.public_id
    assert_includes com_report.map { |row| row.fetch(:contact_public_id) }, com_telephone.public_id
    assert_not_includes com_report.map { |row| row.fetch(:principal_public_id) }, app_client.public_id
    assert_not_includes app_report.to_json, "+12025550114"
    assert_not_includes com_report.to_json, "+12025550115"
  end

  test "detects cleanup attempts at ten and above but not nine or completed cleanup" do
    address = "exhausted-app-#{SecureRandom.hex(6)}@example.com"
    client = Client.create!(
      public_id: PublicId.generate,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    email = ClientEmail.create!(
      user_id: client.id,
      address:,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )

    client_id = "core-app-jp"
    oidc_client = OidcClientRegistry.find!(client_id)
    nonce = SecureRandom.urlsafe_base64(32)
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_up",
      params: {
        client_id:,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: oidc_client.redirect_uris_by_realm.fetch("client").first,
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        prompt: "create",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction:,
      base_browser_nonce: nonce,
      base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app",
      reference: issuance.reference,
    )
    auth_session_class = binding.class.auth_admission_session_class
    attached_session, raw_auth_sid = auth_session_class.issue!
    binding.attach_auth_session!(auth_session: attached_session, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app",
        entry_ref: issuance.reference,
        nonce:,
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
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding,
      principal_id: client.id,
      pending_contact_type: "email",
      pending_contact_id: email.id,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      entry_method: "email",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(8)),
      issued_at: flow_now - 2.minutes,
      expires_at: flow_now - 1.minute,
    )

    assert_empty SignUpStuckRegistrationReportQuery.call(surface: :app)

    flow.expire_sign_up!
    cleanup_status_id = flow.cleanup_status_id_for(:failed)
    [9, 10, 11].each do |attempt_count|
      flow.update!(cleanup_attempts_count: attempt_count, cleanup_status_id:)
      report = SignUpStuckRegistrationReportQuery.call(surface: :app)
      matching = report.select { |row| row.fetch(:flow_public_id) == flow.public_id }

      if attempt_count == 9
        assert_empty matching, "nine failed cleanup attempts are below the retry cap"
      else
        assert_equal 1, matching.length, "#{attempt_count} failed cleanup attempts meet the retry cap"
        assert_equal "cleanup_attempts_exhausted", matching.first.fetch(:case)
        assert_equal attempt_count, matching.first.fetch(:cleanup_attempts_count)
        assert_equal client.public_id, matching.first.fetch(:principal_public_id)
        assert_equal email.public_id, matching.first.fetch(:contact_public_id)
      end
    end

    client.update!(status_id: ClientStatus::ACTIVE)

    assert_empty SignUpStuckRegistrationReportQuery.call(surface: :app)

    client.update!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    flow.update!(cleanup_status_id: flow.cleanup_status_id_for(:completed))

    assert_empty SignUpStuckRegistrationReportQuery.call(surface: :app)
  end

  test "refuses an explicit writing role and an unsupported ORG surface" do
    ActiveRecord::Base.connected_to(role: :writing) do
      assert_raises(SignUpStuckRegistrationReportQuery::WritingRoleRefused) do
        SignUpStuckRegistrationReportQuery.call(surface: :app)
      end
    end

    assert_raises(KeyError) { SignUpStuckRegistrationReportQuery.call(surface: :org) }
  end
end
