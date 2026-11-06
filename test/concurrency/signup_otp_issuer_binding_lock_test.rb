# frozen_string_literal: true

require "test_helper"
require "timeout"

class SignupOtpIssuerBindingLockTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "Email signup OP commit failure leaves no challenge, cooldown change, or delivery job" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = owner.client_emails.create!(
      address: "signup-op-commit-failure-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
    )
    previous_cooldown = email.otp_last_sent_at
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    parent_id = binding.authorization_transaction_id
    session_ids = [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id]
    now = ClientSignUpFlow.database_now
    nonce = SecureRandom.hex(32)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "email", pending_contact_type: "email",
      pending_contact_id: email.id,
    )
    prior_transaction_count = ClientEmailCeremonyTransaction.where(actor_ref: owner.public_id).count
    queued_email_jobs_before =
      ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }
    op_connection = ClientEmailCeremonyTransaction.lease_connection
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected sign-up OP commit failure" }

    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      op_connection.stub(:commit_db_transaction, failed_commit) do
        EmailSignUpOtpDeliveryIssuer.call(flow:, email:, session_nonce: nonce)
      end
    end

    assert_equal prior_transaction_count, ClientEmailCeremonyTransaction.where(actor_ref: owner.public_id).count
    assert_equal previous_cooldown, email.reload.otp_last_sent_at
    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow.reload.status_id
    assert_equal "contact", flow.step
    queued_email_jobs_after =
      ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_equal queued_email_jobs_before, queued_email_jobs_after
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: session_ids.compact).delete_all if session_ids
    ClientOidcAuthorizationTransaction.where(id: parent_id).delete_all if parent_id
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      email&.delete
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      owner.delete
    end
  end

  test "Telephone signup OP commit failure leaves no challenge or SMS job" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = owner.client_telephones.create!(
      number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}", confirm_policy: "1",
    )
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    parent_id = binding.authorization_transaction_id
    session_ids = [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id]
    now = ClientSignUpFlow.database_now
    nonce = SecureRandom.hex(32)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: now + 15.minutes, entry_method: "telephone", pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
    )
    prior_transaction_count = ClientTelephoneCeremonyTransaction.where(actor_ref: owner.public_id).count
    queued_sms_jobs_before =
      ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job.fetch(:job) == Outbound::SmsDeliveryJob }
    op_connection = ClientTelephoneCeremonyTransaction.lease_connection
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected telephone sign-up OP commit failure" }

    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      op_connection.stub(:commit_db_transaction, failed_commit) do
        TelephoneSignUpOtpDeliveryIssuer.call(flow:, telephone:, session_nonce: nonce)
      end
    end

    assert_equal prior_transaction_count,
                 ClientTelephoneCeremonyTransaction.where(actor_ref: owner.public_id).count
    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow.reload.status_id
    assert_equal "contact", flow.step
    queued_sms_jobs_after =
      ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job.fetch(:job) == Outbound::SmsDeliveryJob }

    assert_equal queued_sms_jobs_before, queued_sms_jobs_after
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
    ClientSignUpFlow.where(id: flow.id).delete_all if flow
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
    ClientAuthCeremonySession.where(id: session_ids.compact).delete_all if session_ids
    ClientOidcAuthorizationTransaction.where(id: parent_id).delete_all if parent_id
    if owner
      ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
      telephone&.delete
      ClientAuthorityLock.where(client_id: owner.id).delete_all
      owner.delete
    end
  end

  [[:email, ClientEmail, ClientEmailCeremonyTransaction, EmailSignUpOtpIssuer],
   [:telephone, ClientTelephone, ClientTelephoneCeremonyTransaction,
    TelephoneSignUpOtpIssuer,],].product(%i(expiry destination)).each do |entry, field|
    channel, contact_model, transaction_model, issuer = entry
    test "#{channel} issuer rechecks #{field} after waiting for the transaction lock" do
      owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
      attributes =
        if channel == :email
          { address: "binding-race-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1" }
        else
          { number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}",
            confirm_policy: "1", }
        end
      contact = contact_model.create!(**attributes, user: owner)
      previous_cooldown = contact.otp_last_sent_at
      binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
      parent_id = binding.authorization_transaction_id
      session_ids = [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id]
      now = ClientSignUpFlow.database_now
      nonce = SecureRandom.hex(32)
      flow = ClientSignUpFlow.create!(
        auth_admission_binding: binding, principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
        step: "contact", nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
        expires_at: now + 15.minutes,
        entry_method: channel.to_s, pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )
      reference = Digest::SHA256.hexdigest(JSON.generate(["#{channel}_sign_up", flow.public_id, flow.nonce_digest]))
      binding_fields =
        if channel == :email
          { email_candidate_ref: contact.public_id, normalized_email_digest: contact.address_digest }
        else
          { telephone_candidate_ref: contact.public_id, normalized_number_digest: contact.number_digest }
        end
      transaction = transaction_model.create_transaction!(
        **binding_fields, operation: "sign_up", actor_ref: owner.public_id, session_ref: reference,
                          transaction_id: PublicId.generate, expires_at: flow.expires_at,
      )
      worker = nil
      started = Queue.new
      transaction.with_lock do
        holder_pid = transaction_model.lease_connection.select_value("SELECT pg_backend_pid()").to_i
        worker =
          Thread.new do
            OpBaseAppRecord.connection_pool.with_connection do |connection|
              started << connection.select_value("SELECT pg_backend_pid()").to_i
              issuer.call(
                :flow => ClientSignUpFlow.find(flow.id), channel => contact_model.find(contact.id),
                :session_nonce => nonce,
              )
            end
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        worker_pid = Timeout.timeout(10) { started.pop }
        Timeout.timeout(10) do
          loop do
            blocked =
              transaction_model.uncached do
                transaction_model.lease_connection.select_value(
                  "SELECT #{Integer(holder_pid)} = ANY(pg_blocking_pids(#{Integer(worker_pid)}))",
                )
              end
            break if blocked

            Thread.pass
          end
        end
        changes =
          case field
          when :expiry then { expires_at: flow.expires_at + 1.second }
          when :destination
            if channel == :email
              { normalized_email_digest: IdentifierBlindIndex.bidx_for_email("other@example.test", realm: :app) }
            else
              { normalized_number_digest: IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm: :app) }
            end
          end
        transaction.update!(changes)
      end
      result = Timeout.timeout(10) { worker.value }

      assert_equal :binding_mismatch, result.status
      assert_nil result.code
      assert_nil transaction.reload.otp_generation
      assert_withheld("the Source cooldown remains unchanged") { previous_cooldown == contact.reload.otp_last_sent_at }
    ensure
      worker&.kill unless worker&.join(10)
      transaction_model.where(id: transaction.id).delete_all if transaction
      ClientSignUpFlow.where(id: flow.id).delete_all if flow
      ClientAuthAdmissionBinding.where(id: binding.id).delete_all if binding
      ClientAuthCeremonySession.where(id: session_ids.compact).delete_all if session_ids
      ClientOidcAuthorizationTransaction.where(id: parent_id).delete_all if parent_id
      if owner
        ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
        contact_model.where(id: contact.id).delete_all if contact
        ClientAuthorityLock.where(client_id: owner.id).delete_all
        Client.where(id: owner.id).delete_all
      end
    end
  end
end
