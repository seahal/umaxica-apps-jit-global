# frozen_string_literal: true

require "test_helper"
require "timeout"

class SignUpOtpDeliveryEnqueueObservation
  def initialize(observer)
    @observer = observer
  end

  def perform_later(...)
    @observer.call(...)
  end
end

class SignUpOtpDeliveryConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "telephone signup refuses an outer Source or Ticket transaction before issuing or enqueueing" do
    flow = ClientSignUpFlow.new
    telephone = ClientTelephone.new
    enqueued = []
    transactions_before = ClientTelephoneCeremonyTransaction.count

    Outbound::SmsDeliveryJob.stub(
      :perform_later,
      lambda do |*|
        enqueued << true
        false
      end,
    ) do
      Client.connection_class_for_self.connected_to(role: :writing) do
        Client.transaction do
          assert_raises(TelephoneSignUpOtpDeliveryIssuer::DeliveryUnavailable) do
            TelephoneSignUpOtpDeliveryIssuer.call(
              flow: flow, telephone: telephone, session_nonce: "browser", initial_submission: true,
              actor_context: Actor.authn,
            )
          end
        end
      end

      OpBaseAppRecord.connected_to(role: :writing) do
        ClientSignUpFlow.transaction do
          assert_raises(TelephoneSignUpOtpDeliveryIssuer::DeliveryUnavailable) do
            TelephoneSignUpOtpDeliveryIssuer.call(
              flow: flow, telephone: telephone, session_nonce: "browser", initial_submission: true,
              actor_context: Actor.authn,
            )
          end
        end
      end
    end

    assert_empty enqueued
    assert_equal transactions_before, ClientTelephoneCeremonyTransaction.count
  end

  test "initial Email signup commits Flow binding and OTP generation before enqueue" do
    fixture = create_initial_signup_fixture(channel: :email)
    events = []
    notify =
      lambda do |**|
        events << :enqueued
        true
      end
    after_commit =
      lambda do |issued|
        events << :committed

        assert_initial_signup_state_visible(fixture, issued)
      end

    Chronicle.stub(:capture, ->(**) { }) do
      Notify::App::OtpNotifier.stub(:issue, notify) do
        issued = EmailSignUpOtpDeliveryIssuer.call(
          flow: fixture.fetch(:flow), email: fixture.fetch(:contact),
          session_nonce: fixture.fetch(:nonce), initial_submission: true,
          actor_context: Actor.authn, after_commit:,
        )

        assert_predicate issued, :success?
        assert_equal %i(committed enqueued), events
        assert_initial_signup_state(fixture, issued)
      end
    end
  ensure
    cleanup_initial_signup_fixture(fixture) if fixture
  end

  test "initial Telephone signup commits Flow binding and OTP generation before enqueue" do
    fixture = create_initial_signup_fixture(channel: :telephone)
    events = []
    after_commit =
      lambda do |issued|
        events << :committed

        assert_initial_signup_state_visible(fixture, issued)
      end
    accepted = OutboundResult.accepted(channel: :sms)

    OutboundSms.stub(
      :deliver_later,
      lambda do |**|
        events << :enqueued
        accepted
      end,
    ) do
      issued = TelephoneSignUpOtpDeliveryIssuer.call(
        flow: fixture.fetch(:flow), telephone: fixture.fetch(:contact),
        session_nonce: fixture.fetch(:nonce), initial_submission: true,
        actor_context: Actor.authn, after_commit:,
      )

      assert_predicate issued, :success?
      assert_equal %i(committed enqueued), events
      assert_initial_signup_state(fixture, issued)
    end
  ensure
    cleanup_initial_signup_fixture(fixture) if fixture
  end

  test "initial signup refusal leaves the Flow unbound and creates no OTP generation" do
    %i(email telephone).each do |channel|
      begin
        fixture = create_initial_signup_fixture(channel:)
        contact = fixture.fetch(:contact)
        contact.update!(otp_last_sent_at: contact.class.database_now)
        callback_calls = 0
        enqueue_calls = 0
        issuer =
          if channel == :email
            Notify::App::OtpNotifier.stub(:issue, ->(**) { enqueue_calls += 1 }) do
              EmailSignUpOtpDeliveryIssuer.call(
                flow: fixture.fetch(:flow), email: contact, session_nonce: fixture.fetch(:nonce),
                initial_submission: true, actor_context: Actor.authn,
                after_commit: ->(_) { callback_calls += 1 },
              )
            end
          elsif channel == :telephone
            OutboundSms.stub(:deliver_later, ->(**) { enqueue_calls += 1 }) do
              TelephoneSignUpOtpDeliveryIssuer.call(
                flow: fixture.fetch(:flow), telephone: contact, session_nonce: fixture.fetch(:nonce),
                initial_submission: true, actor_context: Actor.authn,
                after_commit: ->(_) { callback_calls += 1 },
              )
            end
          else
            raise ArgumentError, "unsupported signup channel"
          end

        assert_equal :rate_limited, issuer.status
        assert_equal 0, callback_calls
        assert_equal 0, enqueue_calls
        assert_initial_signup_flow_unbound(fixture)
        assert_equal 0, initial_signup_transaction_model(channel).where(
          session_ref: initial_signup_session_ref(fixture, channel),
        ).count
      ensure
        cleanup_initial_signup_fixture(fixture) if fixture
      end
    end
  end

  test "initial signup refusal after phase transition rolls the Flow back to start" do
    %i(email telephone).each do |channel|
      begin
        fixture = create_initial_signup_fixture(channel:)
        cooldown =
          case channel
          when :email then EmailOtpPolicy::SEND_COOLDOWN
          when :telephone then TelephoneOtpPolicy::SEND_COOLDOWN
          else raise ArgumentError, "unsupported signup channel"
          end
        contact = fixture.fetch(:contact)
        contact.update!(otp_last_sent_at: contact.class.database_now - cooldown - 1.second)
        transaction = seed_cancelled_initial_signup_transaction(fixture)
        original_cooldown = contact.reload.otp_last_sent_at
        callback_calls = 0
        enqueue_calls = 0
        issued =
          if channel == :email
            Chronicle.stub(:capture, ->(**) { }) do
              Notify::App::OtpNotifier.stub(:issue, ->(**) { enqueue_calls += 1 }) do
                EmailSignUpOtpDeliveryIssuer.call(
                  flow: fixture.fetch(:flow), email: fixture.fetch(:contact), session_nonce: fixture.fetch(:nonce),
                  initial_submission: true, actor_context: Actor.authn,
                  after_commit: ->(_) { callback_calls += 1 },
                )
              end
            end
          elsif channel == :telephone
            OutboundSms.stub(:deliver_later, ->(**) { enqueue_calls += 1 }) do
              TelephoneSignUpOtpDeliveryIssuer.call(
                flow: fixture.fetch(:flow), telephone: fixture.fetch(:contact),
                session_nonce: fixture.fetch(:nonce), initial_submission: true,
                actor_context: Actor.authn, after_commit: ->(_) { callback_calls += 1 },
              )
            end
          else
            raise ArgumentError, "unsupported signup channel"
          end

        assert_equal :closed_challenge, issued.status
        assert_equal 0, callback_calls
        assert_equal 0, enqueue_calls
        assert_initial_signup_flow_unbound(fixture)
        assert_equal transaction.otp_generation, transaction.reload.otp_generation
        assert_predicate transaction.reload.otp_cancelled_at, :present?
        assert_equal original_cooldown, contact.reload.otp_last_sent_at
      ensure
        cleanup_initial_signup_fixture(fixture) if fixture
      end
    end
  end

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
        OpBaseAppRecord.connection_pool.with_connection do
          EmailSignUpOtpDeliveryGuard.call(
            flow: ClientSignUpFlow.find(flow.id), email: ClientEmail.find(email.id),
            transaction: ClientEmailCeremonyTransaction.find(issued.transaction.id),
            generation: issued.transaction.otp_generation, destination: email.address, code: issued.code,
          ) do
            delivery_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
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
        OpBaseAppRecord.connection_pool.with_connection do
          cancellation_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
          SignUpTermination.call(cycle: ClientSignUpFlow.find(flow.id), event: :cancel)
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    cancellation_pid = Timeout.timeout(10) { cancellation_started.pop }
    connection = Client.lease_connection
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

  test "email signup refuses an outer Source or Ticket transaction before issuing or enqueueing" do
    flow = ClientSignUpFlow.new
    email = ClientEmail.new
    enqueued = []
    transactions_before = ClientEmailCeremonyTransaction.count

    Notify::App::OtpNotifier.stub(:issue, ->(**) { enqueued << true }) do
      Client.connection_class_for_self.connected_to(role: :writing) do
        Client.transaction do
          assert_raises(EmailSignUpOtpDeliveryIssuer::DeliveryUnavailable) do
            EmailSignUpOtpDeliveryIssuer.call(
              flow: flow, email: email, session_nonce: "browser", initial_submission: true,
              actor_context: Actor.authn,
            )
          end
        end
      end

      OpBaseAppRecord.connected_to(role: :writing) do
        ClientSignUpFlow.transaction do
          assert_raises(EmailSignUpOtpDeliveryIssuer::DeliveryUnavailable) do
            EmailSignUpOtpDeliveryIssuer.call(
              flow: flow, email: email, session_nonce: "browser", initial_submission: true,
              actor_context: Actor.authn,
            )
          end
        end
      end
    end

    assert_empty enqueued
    assert_equal transactions_before, ClientEmailCeremonyTransaction.count
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
    test_case = self
    enqueue_observation =
      lambda do |*_, **_|
        source_transaction_open =
          Client.connection_class_for_self.connected_to(role: :writing) do
            Client.lease_connection.transaction_open?
          end
        ticket_transaction_open =
          OpBaseAppRecord.connected_to(role: :writing) do
            ClientSignUpFlow.lease_connection.transaction_open?
          end

        test_case.assert_not source_transaction_open
        test_case.assert_not ticket_transaction_open

        source_backend_pid =
          Client.connection_class_for_self.connected_to(role: :writing) do
            Client.lease_connection.select_value("SELECT pg_backend_pid()").to_i
          end
        ticket_backend_pid =
          OpBaseAppRecord.connected_to(role: :writing) do
            ClientSignUpFlow.lease_connection.select_value("SELECT pg_backend_pid()").to_i
          end
        observed =
          Timeout.timeout(10) do
            Thread.new do
              source_state =
                Client.connection_class_for_self.connected_to(role: :writing) do
                  Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                    [
                      connection.select_value("SELECT pg_backend_pid()").to_i,
                      ClientEmail.find(email.id).otp_last_sent_at,
                    ]
                  end
                end
              ticket_state =
                OpBaseAppRecord.connected_to(role: :writing) do
                  OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                    [
                      connection.select_value("SELECT pg_backend_pid()").to_i,
                      ClientEmailCeremonyTransaction.find(issued.transaction.id).otp_generation,
                    ]
                  end
                end

              [source_state, ticket_state]
            end.value
          end

        test_case.assert_not_equal source_backend_pid, observed.fetch(0).fetch(0)
        test_case.assert_not_equal ticket_backend_pid, observed.fetch(1).fetch(0)
        test_case.assert_operator observed.fetch(0).fetch(1), :>, original_cooldown
        test_case.assert_not_equal old_generation, observed.fetch(1).fetch(1)

        false
      end
    refused_job = SignUpOtpDeliveryEnqueueObservation.new(enqueue_observation)

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
    queue_calls = 0
    OutboundSms.stub(:provider, Object.new) do
      Outbound::SmsDeliveryJob.stub(
        :perform_later,
        lambda do |**|
          queue_calls += 1
          source_transaction_open =
            Client.connection_class_for_self.connected_to(role: :writing) do
              Client.lease_connection.transaction_open?
            end
          ticket_transaction_open =
            OpBaseAppRecord.connected_to(role: :writing) do
              ClientSignUpFlow.lease_connection.transaction_open?
            end

          assert_not source_transaction_open
          assert_not ticket_transaction_open

          enqueue_backend_pid =
            OpBaseAppRecord.connected_to(role: :writing) do
              ClientSignUpFlow.lease_connection.select_value("SELECT pg_backend_pid()").to_i
            end
          observed =
            Timeout.timeout(10) do
              Thread.new do
                OpBaseAppRecord.connected_to(role: :writing) do
                  ClientSignUpFlow.connection_pool.with_connection(
                    prevent_permanent_checkout: true,
                  ) do |connection|
                    [
                      connection.select_value("SELECT pg_backend_pid()").to_i,
                      ClientTelephoneCeremonyTransaction.find_by!(
                        transaction_id: issued.transaction.transaction_id,
                      ).otp_generation,
                    ]
                  end
                end
              end.value
            end

          assert_not_equal enqueue_backend_pid, observed.fetch(0)
          assert_not_equal old_generation, observed.fetch(1)

          false
        end,
      ) do
        assert_raises(ActiveJob::EnqueueError) do
          TelephoneSignUpOtpDeliveryIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
        end
      end
    end

    assert_equal 1, queue_calls
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
        cancellation_locked << Client.lease_connection.select_value("SELECT pg_backend_pid()")
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
        OpBaseAppRecord.connection_pool.with_connection do
          delivery_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
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
    connection = Client.lease_connection
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
        cancellation_locked << Client.lease_connection.select_value("SELECT pg_backend_pid()")
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
        OpBaseAppRecord.connection_pool.with_connection do
          delivery_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
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
    connection = Client.lease_connection
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
        OpBaseAppRecord.connection_pool.with_connection do
          TelephoneSignUpOtpDeliveryGuard.call(
            flow: ClientSignUpFlow.find(flow.id), telephone: ClientTelephone.find(telephone.id),
            transaction: ClientTelephoneCeremonyTransaction.find(issued.transaction.id),
            generation: issued.transaction.otp_generation, destination: telephone.number, code: issued.code,
          ) do
            delivery_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
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
        OpBaseAppRecord.connection_pool.with_connection do
          cancellation_started << Client.lease_connection.select_value("SELECT pg_backend_pid()")
          SignUpTermination.call(cycle: ClientSignUpFlow.find(flow.id), event: :cancel)
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    cancellation_pid = Timeout.timeout(10) { cancellation_started.pop }
    connection = Client.lease_connection
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

  private

  def create_initial_signup_fixture(channel:)
    fixture = { channel: channel }
    fixture[:binding] = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    fixture[:owner] = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    fixture[:contact] =
      case channel
      when :email
        ClientEmail.create!(
          user: fixture.fetch(:owner), address: "initial-otp-#{SecureRandom.hex(10)}@example.test",
          confirm_policy: "1", user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
        )
      when :telephone
        ClientTelephone.create!(
          user: fixture.fetch(:owner),
          number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}",
          confirm_policy: "1", user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        )
      else
        raise ArgumentError, "unsupported signup channel: #{channel.inspect}"
      end
    fixture[:nonce] = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    fixture[:flow] = ClientSignUpFlow.create!(
      auth_admission_binding: fixture.fetch(:binding),
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(fixture.fetch(:nonce)),
      issued_at: now, expires_at: now + 15.minutes, entry_method: channel.to_s,
      completed_requirements: {},
    )
    fixture
  rescue StandardError
    cleanup_initial_signup_fixture(fixture) if fixture
    raise
  end

  def assert_initial_signup_state(fixture, issued)
    flow = fixture.fetch(:flow).reload

    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow.status_id
    assert_equal "contact", flow.step
    assert_equal fixture.fetch(:owner).id, flow.principal_id
    assert_equal fixture.fetch(:channel).to_s, flow.pending_contact_type
    assert_equal fixture.fetch(:contact).id, flow.pending_contact_id
    assert_predicate fixture.fetch(:contact).reload.otp_last_sent_at, :present?

    transaction = initial_signup_transaction_model(fixture.fetch(:channel)).find_by!(
      transaction_id: issued.transaction.transaction_id,
    )

    assert_equal issued.transaction.otp_generation, transaction.otp_generation
  end

  def assert_initial_signup_flow_unbound(fixture)
    flow = fixture.fetch(:flow).reload

    assert_equal ClientSignUpFlowStatus::STARTED, flow.status_id
    assert_equal "start", flow.step
    assert_nil flow.principal_id
    assert_nil flow.pending_contact_type
    assert_nil flow.pending_contact_id
  end

  def assert_initial_signup_state_visible(fixture, issued)
    assert_initial_signup_transactions_closed

    observed = independent_initial_signup_state(fixture, issued)

    assert_not_equal observed.fetch(:source_backend), observed.fetch(:current_source_backend)
    assert_not_equal observed.fetch(:ticket_backend), observed.fetch(:current_ticket_backend)
    assert_predicate observed.fetch(:cooldown), :present?
    flow = observed.fetch(:flow)

    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow.status_id
    assert_equal fixture.fetch(:owner).id, flow.principal_id
    assert_equal fixture.fetch(:contact).id, flow.pending_contact_id
    assert_equal issued.transaction.otp_generation, observed.fetch(:otp_generation)
  end

  def assert_initial_signup_transactions_closed
    source_connection_open =
      Client.connection_class_for_self.connected_to(role: :writing) do
        Client.lease_connection.transaction_open?
      end
    ticket_connection_open =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientSignUpFlow.lease_connection.transaction_open?
      end

    assert_not source_connection_open
    assert_not ticket_connection_open
  end

  def independent_initial_signup_state(fixture, issued)
    source_backend, ticket_backend = current_initial_signup_backends
    observed =
      Timeout.timeout(10) do
        Thread.new do
          source_state =
            Client.connection_class_for_self.connected_to(role: :writing) do
              Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                contact = fixture.fetch(:contact).class.find(fixture.fetch(:contact).id)
                [connection.select_value("SELECT pg_backend_pid()").to_i, contact.otp_last_sent_at]
              end
            end
          ticket_state =
            OpBaseAppRecord.connected_to(role: :writing) do
              OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                flow = ClientSignUpFlow.find(fixture.fetch(:flow).id)
                transaction = initial_signup_transaction_model(fixture.fetch(:channel)).find_by!(
                  transaction_id: issued.transaction.transaction_id,
                )
                [connection.select_value("SELECT pg_backend_pid()").to_i, flow, transaction.otp_generation]
              end
            end
          [source_state, ticket_state]
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end.value
      end

    {
      current_source_backend: source_backend,
      current_ticket_backend: ticket_backend,
      source_backend: observed.fetch(0).fetch(0),
      cooldown: observed.fetch(0).fetch(1),
      ticket_backend: observed.fetch(1).fetch(0),
      flow: observed.fetch(1).fetch(1),
      otp_generation: observed.fetch(1).fetch(2),
    }
  end

  def current_initial_signup_backends
    source_backend =
      Client.connection_class_for_self.connected_to(role: :writing) do
        Client.lease_connection.select_value("SELECT pg_backend_pid()").to_i
      end
    ticket_backend =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientSignUpFlow.lease_connection.select_value("SELECT pg_backend_pid()").to_i
      end
    [source_backend, ticket_backend]
  end

  def initial_signup_transaction_model(channel)
    case channel
    when :email then ClientEmailCeremonyTransaction
    when :telephone then ClientTelephoneCeremonyTransaction
    else raise ArgumentError, "unsupported signup channel: #{channel.inspect}"
    end
  end

  def seed_cancelled_initial_signup_transaction(fixture)
    owner = fixture.fetch(:owner)
    contact = fixture.fetch(:contact)
    flow = fixture.fetch(:flow)
    transaction_model = initial_signup_transaction_model(fixture.fetch(:channel))
    binding = {
      surface: "app",
      actor_ref: owner.public_id,
      session_ref: initial_signup_session_ref(fixture, fixture.fetch(:channel)),
      operation: "sign_up",
      expires_at: flow.expires_at,
    }
    transaction =
      case contact
      when ClientEmail
        transaction_model.create_transaction!(
          **binding, email_candidate_ref: contact.public_id, normalized_email_digest: contact.address_digest,
        )
      when ClientTelephone
        transaction_model.create_transaction!(
          **binding, telephone_candidate_ref: contact.public_id, normalized_number_digest: contact.number_digest,
        )
      else
        raise ArgumentError, "unsupported signup contact: #{contact.class.name}"
      end
    case fixture.fetch(:channel)
    when :email
      transaction.issue_email_otp!(purpose: "sign_up")
      transaction.cancel_email_otp!
    when :telephone
      transaction.issue_telephone_otp!(purpose: "sign_up")
      transaction.cancel_telephone_otp!
    else
      raise ArgumentError, "unsupported signup channel"
    end
    transaction.reload
  end

  def initial_signup_session_ref(fixture, channel)
    prefix =
      case channel
      when :email then "email_sign_up"
      when :telephone then "telephone_sign_up"
      else raise ArgumentError, "unsupported signup channel: #{channel.inspect}"
      end
    flow = fixture.fetch(:flow)
    Digest::SHA256.hexdigest(JSON.generate([prefix, flow.public_id, flow.nonce_digest]))
  end

  def cleanup_initial_signup_fixture(fixture)
    return unless fixture

    flow = fixture[:flow]
    channel = fixture[:channel]
    if flow && channel
      initial_signup_transaction_model(channel).where(session_ref: initial_signup_session_ref(fixture, channel))
        .delete_all
      ClientSignUpFlow.where(id: flow.id).delete_all
    end

    binding = fixture[:binding]
    if binding
      session_ids = [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id].compact
      parent_id = binding.authorization_transaction_id
      ClientAuthAdmissionBinding.where(id: binding.id).delete_all
      ClientAuthCeremonySession.where(id: session_ids).delete_all
      ClientOidcAuthorizationTransaction.where(id: parent_id).delete_all if parent_id
    end

    owner = fixture[:owner]
    return unless owner

    ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
    ClientEmail.where(id: fixture[:contact].id).delete_all if fixture[:contact].is_a?(ClientEmail)
    ClientTelephone.where(id: fixture[:contact].id).delete_all if fixture[:contact].is_a?(ClientTelephone)
    ClientAuthorityLock.where(client_id: owner.id).delete_all
    Client.where(id: owner.id).delete_all
  end
end
