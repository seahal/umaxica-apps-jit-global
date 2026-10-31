# frozen_string_literal: true

require "test_helper"
require "timeout"

class StepUpEmailDeliveryReleaseRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "release waits for a started delivery and the delivered code cannot verify afterward" do
    actor = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )
    email = actor.client_emails.create!(
      address: "step-up-race-#{SecureRandom.hex(8)}@example.test", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = ClientToken.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, authentication_epoch: 0, user: actor,
    )
    device = token.device_session_record!
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_email",
      required_aal: "none", allowed_methods: ["email_otp"], return_to: "/identity/emails",
    )
    record = ClientStepUpSession.create!(
      user_token: token, step_up_ceremony_transaction_ref: transaction.transaction_id,
      scope: transaction.required_scope, return_to: transaction.return_to,
      status: "PENDING", discard_at: transaction.expires_at,
    )
    generation = record.issue_bound_email_code!(transaction: transaction, credential_ref: email.public_id, code: "012345")
    ciphertext = OutboundSensitivePayload.encrypt_email_otp("012345")
    sending = Queue.new
    proceed = Queue.new
    release_ready = Queue.new
    released = Queue.new
    delivery = release = nil
    original_with = Email::App::OtpMailer.method(:with)
    paused_with = lambda do |**arguments|
      sending << true
      proceed.pop
      original_with.call(**arguments)
    end

    Email::App::OtpMailer.stub(:with, paused_with) do
      delivery = Thread.new do
        IdentityStepUpEmailDeliveryRecorder.call!(
          credential: ClientEmail.find(email.id), transaction_ref: transaction.transaction_id,
          generation: generation, encrypted_code: ciphertext,
        )
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
      Timeout.timeout(10) { sending.pop }
      release = Thread.new do
        ClientEmail.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
          release_ready << connection.select_value("SELECT pg_backend_pid()").to_i
          ClientEmail.find(email.id).release_binding!
          released << true
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
      pid = Timeout.timeout(10) { release_ready.pop }
      blocked = Timeout.timeout(5) do
        loop do
          break false unless released.empty?

          waiting = ClientEmail.uncached do
            ClientEmail.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
          end
          break true if waiting

          Thread.pass
        end
      end
      proceed << true
      assert blocked
      assert Timeout.timeout(10) { delivery.value }
      assert Timeout.timeout(10) { release.value }
    end

    assert_not IdentityStepUpEmailVerificationCommitter.call!(
      actor: actor, credential: email.reload, transaction: transaction.reload, session_record: record.reload,
      code: "012345",
    )
    assert_nil record.reload.email_code_consumed_at
  ensure
    proceed << true if proceed
    delivery&.join(10)
    release&.join(10)
    record&.delete
    transaction&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    email&.delete
    actor&.delete
    ActionMailer::Base.deliveries.clear
  end
end
