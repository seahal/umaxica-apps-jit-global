# frozen_string_literal: true

require "test_helper"
require "timeout"

class SignUpOtpDeliveryConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "email cancellation waits for the current delivery and makes its code unusable" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "delivery-race-#{SecureRandom.hex(10)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)

    assert_predicate issued, :success?
    delivery_started = Queue.new
    release_delivery = Queue.new
    cancellation_started = Queue.new
    delivery =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          EmailSignUpOtpDeliveryGuard.call(
            flow: ClientSignUpFlow.find(flow.id), email: ClientEmail.find(email.id),
            transaction: ClientEmailCeremonyTransaction.find(issued.transaction.id),
            generation: issued.transaction.otp_generation, destination: email.address, code: issued.code,
          ) do
            delivery_started << connection.select_value("SELECT pg_backend_pid()")
            release_delivery.pop
            true
          end
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    delivery_pid = Timeout.timeout(10) { delivery_started.pop }
    cancellation =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          cancellation_started << connection.select_value("SELECT pg_backend_pid()")
          SignUpTermination.call(cycle: ClientSignUpFlow.find(flow.id), event: :cancel)
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    cancellation_pid = Timeout.timeout(10) { cancellation_started.pop }
    connection = OpBaseAppRecord.lease_connection
    Timeout.timeout(10) do
      loop do
        waiting =
          connection.uncached do
            connection.select_value(
              "SELECT #{Integer(delivery_pid)} = ANY(pg_blocking_pids(#{Integer(cancellation_pid)}))",
            )
          end
        break if waiting

        sleep 0.01
      end
    end

    assert_not_equal delivery_pid, cancellation_pid
    release_delivery << true

    assert Timeout.timeout(10) { delivery.value }
    assert_equal :ok, Timeout.timeout(10) { cancellation.value }.status
    verification = EmailSignUpOtpVerificationCommitter.call(
      flow: flow.reload, email: email.reload,
      session_nonce: nonce, code: issued.code,
    )

    assert_not_predicate verification, :success?
    assert_equal :inactive_flow, verification.status
  ensure
    release_delivery << true if release_delivery
    delivery&.kill unless delivery&.join(10)
    cancellation&.kill unless cancellation&.join(10)
    ClientEmailCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientEmail.where(id: email.id).delete_all if email
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "email signup paths wait for the owner before locking the flow" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "delivery-race-#{SecureRandom.hex(10)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)

    assert_predicate issued, :success?
    worker = nil
    actions = [
      -> {
        EmailSignUpOtpDeliveryGuard.call(
          flow: ClientSignUpFlow.find(flow.id), email: ClientEmail.find(email.id),
          transaction: ClientEmailCeremonyTransaction.find(issued.transaction.id),
          generation: issued.transaction.otp_generation,
          destination: email.address, code: issued.code,
        ) { true }
      },
      -> {
        EmailSignUpOtpIssuer.call(
          flow: ClientSignUpFlow.find(flow.id), email: ClientEmail.find(email.id),
          session_nonce: nonce,
        )
      },
      -> {
        EmailSignUpOtpVerificationCommitter.call(
          flow: ClientSignUpFlow.find(flow.id), email: ClientEmail.find(email.id),
          session_nonce: nonce, code: issued.code,
        )
      },
    ]
    actions.each do |action|
      ready = Queue.new
      owner.with_lock do
        holder_pid = Client.lease_connection.select_value("SELECT pg_backend_pid()").to_i
        worker =
          Thread.new do
            Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()").to_i
              action.call
            end
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        worker_pid = Timeout.timeout(10) { ready.pop }
        Timeout.timeout(10) do
          loop do
            waiting =
              Client.uncached do
                Client.lease_connection.select_value(
                  "SELECT #{Integer(holder_pid)} = ANY(pg_blocking_pids(#{Integer(worker_pid)}))",
                )
              end
            break if waiting

            Thread.pass
          end
        end

        ClientSignUpFlow.transaction do
          assert ClientSignUpFlow.lock("FOR UPDATE NOWAIT").find(flow.id)
        end
      end
      Timeout.timeout(10) { worker.value }
    end
  ensure
    worker&.join(10)
    ClientEmailCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientEmail.where(id: email.id).delete_all if email
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "email signup retains the new generation when source cooldown fails" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "delivery-race-#{SecureRandom.hex(10)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)

    assert_predicate issued, :success?
    old_generation = issued.transaction.otp_generation
    email.update!(otp_last_sent_at: ClientEmail.database_now - EmailOtpPolicy::SEND_COOLDOWN - 1.second)
    original_cooldown = email.reload.otp_last_sent_at
    sent = []
    Notify::App::OtpNotifier.stub(:issue, ->(**) { sent << true }) do
      email.stub(:update!, ->(**) { raise ActiveRecord::StatementInvalid, "injected source failure" }) do
        assert_raises(ActiveRecord::StatementInvalid) do
          EmailSignUpOtpDeliveryIssuer.call(flow: flow, email: email, session_nonce: nonce)
        end
      end
    end

    assert_not_equal old_generation, issued.transaction.reload.otp_generation
    assert_equal original_cooldown, email.reload.otp_last_sent_at
    assert_empty sent
    assert_not_predicate flow.reload, :sign_up_terminal?
  ensure
    ClientEmailCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientEmail.where(id: email.id).delete_all if email
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "email signup retains the new generation when the queue refuses delivery" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "delivery-race-#{SecureRandom.hex(10)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)

    assert_predicate issued, :success?
    old_generation = issued.transaction.otp_generation
    email.update!(otp_last_sent_at: ClientEmail.database_now - EmailOtpPolicy::SEND_COOLDOWN - 1.second)
    original_cooldown = email.reload.otp_last_sent_at
    refused_job = Object.new
    refused_job.define_singleton_method(:perform_later) { |*_, **_| false }

    assert_no_difference -> { Chronicle.where(action: "notification.delivery.email.enqueued").count } do
      OtpNotifierEmailDeliveryJob.stub(:set, refused_job) do
        assert_raises(ActiveJob::EnqueueError) do
          EmailSignUpOtpDeliveryIssuer.call(flow: flow, email: email, session_nonce: nonce)
        end
      end
    end

    assert_not_equal old_generation, issued.transaction.reload.otp_generation
    assert_operator email.reload.otp_last_sent_at, :>, original_cooldown
    assert_not_predicate flow.reload, :sign_up_terminal?
  ensure
    ClientEmailCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientEmail.where(id: email.id).delete_all if email
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "telephone signup paths wait for the owner before locking the flow" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = ClientTelephone.create!(
      user: owner, number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}", confirm_policy: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "telephone", pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
    )
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

    assert_predicate issued, :success?
    worker = nil
    actions = [
      -> {
        TelephoneSignUpOtpDeliveryGuard.call(
          flow: ClientSignUpFlow.find(flow.id), telephone: ClientTelephone.find(telephone.id),
          transaction: ClientTelephoneCeremonyTransaction.find(issued.transaction.id),
          generation: issued.transaction.otp_generation,
          destination: telephone.number, code: issued.code,
        ) { true }
      },
      -> {
        TelephoneSignUpOtpIssuer.call(
          flow: ClientSignUpFlow.find(flow.id), telephone: ClientTelephone.find(telephone.id),
          session_nonce: nonce,
        )
      },
      -> {
        TelephoneSignUpOtpVerificationCommitter.call(
          flow: ClientSignUpFlow.find(flow.id), telephone: ClientTelephone.find(telephone.id),
          session_nonce: nonce, code: issued.code,
        )
      },
    ]
    actions.each do |action|
      ready = Queue.new
      owner.with_lock do
        holder_pid = Client.lease_connection.select_value("SELECT pg_backend_pid()").to_i
        worker =
          Thread.new do
            Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()").to_i
              action.call
            end
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        worker_pid = Timeout.timeout(10) { ready.pop }
        Timeout.timeout(10) do
          loop do
            waiting =
              Client.uncached do
                Client.lease_connection.select_value(
                  "SELECT #{Integer(holder_pid)} = ANY(pg_blocking_pids(#{Integer(worker_pid)}))",
                )
              end
            break if waiting

            Thread.pass
          end
        end

        ClientSignUpFlow.transaction do
          assert ClientSignUpFlow.lock("FOR UPDATE NOWAIT").find(flow.id)
        end
      end
      Timeout.timeout(10) { worker.value }
    end
  ensure
    worker&.join(10)
    ClientTelephoneCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientTelephone.where(id: telephone.id).delete_all if telephone
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "telephone signup retains the new generation when source cooldown fails" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = ClientTelephone.create!(
      user: owner, number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}", confirm_policy: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "telephone", pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
    )
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

    assert_predicate issued, :success?
    old_generation = issued.transaction.otp_generation
    telephone.update!(otp_last_sent_at: ClientTelephone.database_now - TelephoneOtpPolicy::SEND_COOLDOWN - 1.second)
    original_cooldown = telephone.reload.otp_last_sent_at
    sent = []
    OutboundSms.stub(:deliver_later, ->(**) { sent << true }) do
      telephone.stub(:update!, ->(**) { raise ActiveRecord::StatementInvalid, "injected source failure" }) do
        assert_raises(ActiveRecord::StatementInvalid) do
          TelephoneSignUpOtpDeliveryIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
        end
      end
    end

    assert_not_equal old_generation, issued.transaction.reload.otp_generation
    assert_equal original_cooldown, telephone.reload.otp_last_sent_at
    assert_empty sent
    assert_not_predicate flow.reload, :sign_up_terminal?
  ensure
    ClientTelephoneCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientTelephone.where(id: telephone.id).delete_all if telephone
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "telephone signup retains the new generation when the queue refuses delivery" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = ClientTelephone.create!(
      user: owner, number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}", confirm_policy: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "telephone", pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
    )
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

    assert_predicate issued, :success?
    old_generation = issued.transaction.otp_generation
    telephone.update!(otp_last_sent_at: ClientTelephone.database_now - TelephoneOtpPolicy::SEND_COOLDOWN - 1.second)
    original_cooldown = telephone.reload.otp_last_sent_at
    OutboundSms.stub(:provider, Object.new) do
      Outbound::SmsDeliveryJob.stub(:perform_later, false) do
        assert_raises(ActiveJob::EnqueueError) do
          TelephoneSignUpOtpDeliveryIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
        end
      end
    end

    assert_not_equal old_generation, issued.transaction.reload.otp_generation
    assert_operator telephone.reload.otp_last_sent_at, :>, original_cooldown
    assert_not_predicate flow.reload, :sign_up_terminal?
  ensure
    ClientTelephoneCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientTelephone.where(id: telephone.id).delete_all if telephone
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "email resend waits for current delivery and then replaces its generation" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "delivery-race-#{SecureRandom.hex(10)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)

    assert_predicate issued, :success?
    old_generation = issued.transaction.otp_generation
    original_expiry = flow.expires_at
    email.update!(otp_last_sent_at: ClientEmail.database_now - EmailOtpPolicy::SEND_COOLDOWN - 1.second)
    sent = Queue.new
    delivery_started = Queue.new
    release_delivery = Queue.new
    resend_started = Queue.new
    delivery =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |_connection|
          EmailSignUpOtpDeliveryGuard.call(
            flow: ClientSignUpFlow.find(flow.id), email: ClientEmail.find(email.id),
            transaction: ClientEmailCeremonyTransaction.find(issued.transaction.id),
            generation: issued.transaction.otp_generation, destination: email.address, code: issued.code,
          ) do
            delivery_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
            release_delivery.pop
            sent << true
            true
          end
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    delivery_pid = Timeout.timeout(10) { delivery_started.pop }
    resend =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |_connection|
          resend_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
          EmailSignUpOtpIssuer.call(
            flow: ClientSignUpFlow.find(flow.id), email: ClientEmail.find(email.id), session_nonce: nonce,
          )
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    resend_pid = Timeout.timeout(10) { resend_started.pop }
    connection = OpBaseAppRecord.lease_connection
    Timeout.timeout(10) do
      loop do
        waiting =
          connection.uncached do
            connection.select_value(
              "SELECT #{Integer(delivery_pid)} = ANY(pg_blocking_pids(#{Integer(resend_pid)}))",
            )
          end
        break if waiting

        sleep 0.01
      end
    end

    assert_not_equal delivery_pid, resend_pid
    release_delivery << true

    assert Timeout.timeout(10) { delivery.value }
    assert sent.pop
    replacement = Timeout.timeout(10) { resend.value }

    assert_predicate replacement, :success?
    assert_not_equal old_generation, replacement.transaction.otp_generation
    assert_equal original_expiry, flow.reload.expires_at
    assert_not_predicate flow, :sign_up_terminal?
    assert_not EmailSignUpOtpDeliveryGuard.call(
      flow: flow, email: email.reload, transaction: issued.transaction.reload,
      generation: old_generation, destination: email.address, code: issued.code,
    ) { flunk("an old generation must not be delivered after resend") }
    verification = EmailSignUpOtpVerificationCommitter.call(
      flow: flow.reload, email: email.reload,
      session_nonce: nonce, code: replacement.code,
    )

    assert_predicate verification, :success?
    assert_equal :verified, verification.status
  ensure
    release_delivery << true if release_delivery
    delivery&.kill unless delivery&.join(10)
    resend&.kill unless resend&.join(10)
    ClientEmailCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientEmail.where(id: email.id).delete_all if email
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "email delivery waits for cancellation and never sends the old code" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "delivery-race-#{SecureRandom.hex(10)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)

    assert_predicate issued, :success?
    cancellation_locked = Queue.new
    release_cancellation = Queue.new
    delivery_started = Queue.new
    sent = Queue.new
    cancellation = nil
    paused = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless Thread.current == cancellation && !paused &&
          event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_sign_up_flows"/i)

        paused = true
        cancellation_locked << OpBaseAppRecord.lease_connection.select_value("SELECT pg_backend_pid()")
        release_cancellation.pop
      end
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record", observer)
    cancellation =
      Thread.new do
        SignUpTermination.call(cycle: ClientSignUpFlow.find(flow.id), event: :cancel)
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    cancellation_pid = Timeout.timeout(10) { cancellation_locked.pop }
    delivery =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          delivery_started << connection.select_value("SELECT pg_backend_pid()")
          EmailSignUpOtpDeliveryGuard.call(
            flow: ClientSignUpFlow.find(flow.id), email: ClientEmail.find(email.id),
            transaction: ClientEmailCeremonyTransaction.find(issued.transaction.id),
            generation: issued.transaction.otp_generation, destination: email.address, code: issued.code,
          ) { sent << true }
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    delivery_pid = Timeout.timeout(10) { delivery_started.pop }
    connection = OpBaseAppRecord.lease_connection
    Timeout.timeout(10) do
      loop do
        waiting =
          connection.uncached do
            connection.select_value(
              "SELECT #{Integer(cancellation_pid)} = ANY(pg_blocking_pids(#{Integer(delivery_pid)}))",
            )
          end
        break if waiting

        sleep 0.01
      end
    end

    assert_not_equal delivery_pid, cancellation_pid
    release_cancellation << true

    assert_equal :ok, Timeout.timeout(10) { cancellation.value }.status
    assert_not Timeout.timeout(10) { delivery.value }
    assert_empty sent
    verification = EmailSignUpOtpVerificationCommitter.call(
      flow: flow.reload, email: email.reload,
      session_nonce: nonce, code: issued.code,
    )

    assert_not_predicate verification, :success?
    assert_equal :inactive_flow, verification.status
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
    release_cancellation << true if release_cancellation
    delivery&.kill unless delivery&.join(10)
    cancellation&.kill unless cancellation&.join(10)
    ClientEmailCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientEmail.where(id: email.id).delete_all if email
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "email old delivery waits for resend and refuses the old generation" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "delivery-race-#{SecureRandom.hex(10)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)

    assert_predicate issued, :success?
    old_generation = issued.transaction.otp_generation
    original_expiry = flow.expires_at
    email.update!(otp_last_sent_at: ClientEmail.database_now - EmailOtpPolicy::SEND_COOLDOWN - 1.second)
    resend_locked = Queue.new
    release_resend = Queue.new
    delivery_started = Queue.new
    sent = Queue.new
    resend = nil
    paused = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless Thread.current == resend && !paused &&
          event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_email_ceremony_transactions"/i)

        paused = true
        resend_locked << Client.lease_connection.select_value("SELECT pg_backend_pid()")
        release_resend.pop
      end
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record", observer)
    resend =
      Thread.new do
        EmailSignUpOtpIssuer.call(
          flow: ClientSignUpFlow.find(flow.id), email: ClientEmail.find(email.id),
          session_nonce: nonce,
        )
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    resend_pid = Timeout.timeout(10) { resend_locked.pop }
    delivery =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |_connection|
          delivery_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
          EmailSignUpOtpDeliveryGuard.call(
            flow: ClientSignUpFlow.find(flow.id), email: ClientEmail.find(email.id),
            transaction: ClientEmailCeremonyTransaction.find(issued.transaction.id),
            generation: old_generation, destination: email.address, code: issued.code,
          ) { sent << true }
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    delivery_pid = Timeout.timeout(10) { delivery_started.pop }
    connection = OpBaseAppRecord.lease_connection
    Timeout.timeout(10) do
      loop do
        waiting =
          connection.uncached do
            connection.select_value(
              "SELECT #{Integer(resend_pid)} = ANY(pg_blocking_pids(#{Integer(delivery_pid)}))",
            )
          end
        break if waiting

        sleep 0.01
      end
    end

    assert_not_equal delivery_pid, resend_pid
    release_resend << true

    replacement = Timeout.timeout(10) { resend.value }

    assert_predicate replacement, :success?
    assert_not_equal old_generation, replacement.transaction.otp_generation
    assert_equal original_expiry, flow.reload.expires_at
    assert_not_predicate flow, :sign_up_terminal?
    assert_not Timeout.timeout(10) { delivery.value }
    assert_empty sent
    verification = EmailSignUpOtpVerificationCommitter.call(
      flow: flow.reload, email: email.reload,
      session_nonce: nonce, code: replacement.code,
    )

    assert_predicate verification, :success?
    assert_equal :verified, verification.status
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
    release_resend << true if release_resend
    delivery&.kill unless delivery&.join(10)
    resend&.kill unless resend&.join(10)
    ClientEmailCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientEmail.where(id: email.id).delete_all if email
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "telephone resend waits for current delivery and then replaces its generation" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = ClientTelephone.create!(
      user: owner, number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}", confirm_policy: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "telephone", pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
    )
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

    assert_predicate issued, :success?
    old_generation = issued.transaction.otp_generation
    original_expiry = flow.expires_at
    telephone.update!(otp_last_sent_at: ClientTelephone.database_now - TelephoneOtpPolicy::SEND_COOLDOWN - 1.second)
    sent = Queue.new
    delivery_started = Queue.new
    release_delivery = Queue.new
    resend_started = Queue.new
    delivery =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |_connection|
          TelephoneSignUpOtpDeliveryGuard.call(
            flow: ClientSignUpFlow.find(flow.id), telephone: ClientTelephone.find(telephone.id),
            transaction: ClientTelephoneCeremonyTransaction.find(issued.transaction.id),
            generation: issued.transaction.otp_generation, destination: telephone.number, code: issued.code,
          ) do
            delivery_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
            release_delivery.pop
            sent << true
            true
          end
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    delivery_pid = Timeout.timeout(10) { delivery_started.pop }
    resend =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |_connection|
          resend_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
          TelephoneSignUpOtpIssuer.call(
            flow: ClientSignUpFlow.find(flow.id), telephone: ClientTelephone.find(telephone.id), session_nonce: nonce,
          )
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    resend_pid = Timeout.timeout(10) { resend_started.pop }
    connection = OpBaseAppRecord.lease_connection
    Timeout.timeout(10) do
      loop do
        waiting =
          connection.uncached do
            connection.select_value(
              "SELECT #{Integer(delivery_pid)} = ANY(pg_blocking_pids(#{Integer(resend_pid)}))",
            )
          end
        break if waiting

        sleep 0.01
      end
    end

    assert_not_equal delivery_pid, resend_pid
    release_delivery << true

    assert Timeout.timeout(10) { delivery.value }
    assert sent.pop
    replacement = Timeout.timeout(10) { resend.value }

    assert_predicate replacement, :success?
    assert_not_equal old_generation, replacement.transaction.otp_generation
    assert_equal original_expiry, flow.reload.expires_at
    assert_not_predicate flow, :sign_up_terminal?
    assert_not TelephoneSignUpOtpDeliveryGuard.call(
      flow: flow, telephone: telephone.reload, transaction: issued.transaction.reload,
      generation: old_generation, destination: telephone.number, code: issued.code,
    ) { flunk("an old generation must not be delivered after resend") }
    verification = TelephoneSignUpOtpVerificationCommitter.call(
      flow: flow.reload, telephone: telephone.reload,
      session_nonce: nonce, code: replacement.code,
    )

    assert_predicate verification, :success?
    assert_equal :verified, verification.status
  ensure
    release_delivery << true if release_delivery
    delivery&.kill unless delivery&.join(10)
    resend&.kill unless resend&.join(10)
    ClientTelephoneCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientTelephone.where(id: telephone.id).delete_all if telephone
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "telephone old delivery waits for resend and refuses the old generation" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = ClientTelephone.create!(
      user: owner, number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}", confirm_policy: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "telephone", pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
    )
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

    assert_predicate issued, :success?
    old_generation = issued.transaction.otp_generation
    original_expiry = flow.expires_at
    telephone.update!(otp_last_sent_at: ClientTelephone.database_now - TelephoneOtpPolicy::SEND_COOLDOWN - 1.second)
    resend_locked = Queue.new
    release_resend = Queue.new
    delivery_started = Queue.new
    sent = Queue.new
    resend = nil
    paused = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless Thread.current == resend && !paused &&
          event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_telephone_ceremony_transactions"/i)

        paused = true
        resend_locked << Client.lease_connection.select_value("SELECT pg_backend_pid()")
        release_resend.pop
      end
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record", observer)
    resend =
      Thread.new do
        TelephoneSignUpOtpIssuer.call(
          flow: ClientSignUpFlow.find(flow.id),
          telephone: ClientTelephone.find(telephone.id), session_nonce: nonce,
        )
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    resend_pid = Timeout.timeout(10) { resend_locked.pop }
    delivery =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |_connection|
          delivery_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
          TelephoneSignUpOtpDeliveryGuard.call(
            flow: ClientSignUpFlow.find(flow.id), telephone: ClientTelephone.find(telephone.id),
            transaction: ClientTelephoneCeremonyTransaction.find(issued.transaction.id),
            generation: old_generation, destination: telephone.number, code: issued.code,
          ) { sent << true }
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    delivery_pid = Timeout.timeout(10) { delivery_started.pop }
    connection = OpBaseAppRecord.lease_connection
    Timeout.timeout(10) do
      loop do
        waiting =
          connection.uncached do
            connection.select_value(
              "SELECT #{Integer(resend_pid)} = ANY(pg_blocking_pids(#{Integer(delivery_pid)}))",
            )
          end
        break if waiting

        sleep 0.01
      end
    end

    assert_not_equal delivery_pid, resend_pid
    release_resend << true

    replacement = Timeout.timeout(10) { resend.value }

    assert_predicate replacement, :success?
    assert_not_equal old_generation, replacement.transaction.otp_generation
    assert_equal original_expiry, flow.reload.expires_at
    assert_not_predicate flow, :sign_up_terminal?
    assert_not Timeout.timeout(10) { delivery.value }
    assert_empty sent
    verification = TelephoneSignUpOtpVerificationCommitter.call(
      flow: flow.reload, telephone: telephone.reload,
      session_nonce: nonce, code: replacement.code,
    )

    assert_predicate verification, :success?
    assert_equal :verified, verification.status
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
    release_resend << true if release_resend
    delivery&.kill unless delivery&.join(10)
    resend&.kill unless resend&.join(10)
    ClientTelephoneCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientTelephone.where(id: telephone.id).delete_all if telephone
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "telephone delivery waits for cancellation and never sends the old code" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = ClientTelephone.create!(
      user: owner, number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}", confirm_policy: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "telephone", pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
    )
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

    assert_predicate issued, :success?
    cancellation_locked = Queue.new
    release_cancellation = Queue.new
    delivery_started = Queue.new
    sent = Queue.new
    cancellation = nil
    paused = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless Thread.current == cancellation && !paused &&
          event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_sign_up_flows"/i)

        paused = true
        cancellation_locked << OpBaseAppRecord.lease_connection.select_value("SELECT pg_backend_pid()")
        release_cancellation.pop
      end
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record", observer)
    cancellation =
      Thread.new do
        SignUpTermination.call(cycle: ClientSignUpFlow.find(flow.id), event: :cancel)
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    cancellation_pid = Timeout.timeout(10) { cancellation_locked.pop }
    delivery =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          delivery_started << connection.select_value("SELECT pg_backend_pid()")
          TelephoneSignUpOtpDeliveryGuard.call(
            flow: ClientSignUpFlow.find(flow.id), telephone: ClientTelephone.find(telephone.id),
            transaction: ClientTelephoneCeremonyTransaction.find(issued.transaction.id),
            generation: issued.transaction.otp_generation, destination: telephone.number, code: issued.code,
          ) { sent << true }
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    delivery_pid = Timeout.timeout(10) { delivery_started.pop }
    connection = OpBaseAppRecord.lease_connection
    Timeout.timeout(10) do
      loop do
        waiting =
          connection.uncached do
            connection.select_value(
              "SELECT #{Integer(cancellation_pid)} = ANY(pg_blocking_pids(#{Integer(delivery_pid)}))",
            )
          end
        break if waiting

        sleep 0.01
      end
    end

    assert_not_equal delivery_pid, cancellation_pid
    release_cancellation << true

    assert_equal :ok, Timeout.timeout(10) { cancellation.value }.status
    assert_not Timeout.timeout(10) { delivery.value }
    assert_empty sent
    verification = TelephoneSignUpOtpVerificationCommitter.call(
      flow: flow.reload, telephone: telephone.reload,
      session_nonce: nonce, code: issued.code,
    )

    assert_not_predicate verification, :success?
    assert_equal :inactive_flow, verification.status
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
    release_cancellation << true if release_cancellation
    delivery&.kill unless delivery&.join(10)
    cancellation&.kill unless cancellation&.join(10)
    ClientTelephoneCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientTelephone.where(id: telephone.id).delete_all if telephone
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end

  test "telephone cancellation waits for the current delivery and makes its code unusable" do
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        prompt: "create",
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference,
        nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = ClientTelephone.create!(
      user: owner, number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}", confirm_policy: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "telephone", pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
    )
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

    assert_predicate issued, :success?
    delivery_started = Queue.new
    release_delivery = Queue.new
    cancellation_started = Queue.new
    delivery =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          TelephoneSignUpOtpDeliveryGuard.call(
            flow: ClientSignUpFlow.find(flow.id), telephone: ClientTelephone.find(telephone.id),
            transaction: ClientTelephoneCeremonyTransaction.find(issued.transaction.id),
            generation: issued.transaction.otp_generation, destination: telephone.number, code: issued.code,
          ) do
            delivery_started << connection.select_value("SELECT pg_backend_pid()")
            release_delivery.pop
            true
          end
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    delivery_pid = Timeout.timeout(10) { delivery_started.pop }
    cancellation =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          cancellation_started << connection.select_value("SELECT pg_backend_pid()")
          SignUpTermination.call(cycle: ClientSignUpFlow.find(flow.id), event: :cancel)
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    cancellation_pid = Timeout.timeout(10) { cancellation_started.pop }
    connection = OpBaseAppRecord.lease_connection
    Timeout.timeout(10) do
      loop do
        waiting =
          connection.uncached do
            connection.select_value(
              "SELECT #{Integer(delivery_pid)} = ANY(pg_blocking_pids(#{Integer(cancellation_pid)}))",
            )
          end
        break if waiting

        sleep 0.01
      end
    end

    assert_not_equal delivery_pid, cancellation_pid
    release_delivery << true

    assert Timeout.timeout(10) { delivery.value }
    assert_equal :ok, Timeout.timeout(10) { cancellation.value }.status
    verification = TelephoneSignUpOtpVerificationCommitter.call(
      flow: flow.reload, telephone: telephone.reload,
      session_nonce: nonce, code: issued.code,
    )

    assert_not_predicate verification, :success?
    assert_equal :inactive_flow, verification.status
  ensure
    release_delivery << true if release_delivery
    delivery&.kill unless delivery&.join(10)
    cancellation&.kill unless cancellation&.join(10)
    ClientTelephoneCeremonyTransaction.where(id: issued.transaction.id).delete_all if issued&.transaction
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: [attached&.id, admitted&.id].compact).delete_all if attached || admitted
    ClientOidcAuthorizationTransaction.where(id: parent.id).delete_all if parent
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      ClientTelephone.where(id: telephone.id).delete_all if telephone
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end
end
