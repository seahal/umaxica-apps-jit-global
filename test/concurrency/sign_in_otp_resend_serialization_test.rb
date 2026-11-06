# frozen_string_literal: true

require "test_helper"
require "timeout"

class SignInOtpResendSerializationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  %i(auth occurrence).product(%i(real fake)).each do |database, contact_mode|
    test "#{contact_mode} resend refuses an outer #{database} transaction before issuance" do
      address = "resend-outer-#{SecureRandom.hex(8)}@example.test"
      body = OccurrenceHmac.digest(kind: :email, body: address)
      if contact_mode == :real
        owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
        contact = owner.client_emails.create!(address:, confirm_policy: "1").tap(&:finalize_binding!)
      end
      admission = OidcTestEntry.issue!(
        surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "authentication_handoff",
        authorization_transaction_ref: admission.transaction.transaction_id,
      )
      ceremony.issue_email_otp!(contact:, destination: address)
      original = ceremony.reload.email_otp_context.deep_dup
      state = SignInOtpResendState.issue(
        kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact:,
      )
      adapter = Minitest::Mock.new
      result = nil
      transaction_class = (database == :auth) ? ClientAuthCeremonySession : EmailOccurrence

      OtpAdapter.stub(:for, adapter) do
        transaction_class.transaction do
          result = SignInOtpResender.new(
            kind: :email, state:, surface: :app, browser_binding: ceremony.sid_digest, ceremony:,
          ).call

          assert_equal :service_unavailable, result.status
          assert_withheld { original == ceremony.reload.email_otp_context }
          assert_not EmailOccurrence.exists?(body:)
          raise ActiveRecord::Rollback
        end
      end

      assert_withheld { original == ceremony.reload.email_otp_context }
      assert_not EmailOccurrence.exists?(body:)
      adapter.verify
    ensure
      EmailOccurrence.where(body:).delete_all if body
      ceremony&.delete
      if admission
        ClientAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id).delete_all
        admission.transaction.delete
      end
      contact&.delete
      owner&.delete
    end
  end

  test "two browsers for one destination serialize the resend cooldown" do
    address = "resend-race-#{SecureRandom.hex(8)}@example.test"
    body = OccurrenceHmac.digest(kind: :email, body: address)
    admissions =
      2.times.map do
        OidcTestEntry.issue!(
          surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32),
          base_token: nil,
        )
      end
    ceremonies =
      admissions.map do |admission|
        ClientAuthCeremonySession.rotate_and_admit!(
          admission_purpose: "authentication_handoff",
          authorization_transaction_ref: admission.transaction.transaction_id,
        ).first
      end
    states =
      ceremonies.map do |ceremony|
        ceremony.issue_email_otp!(contact: nil, destination: address)
        SignInOtpResendState.issue(
          kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact: nil,
        )
      end
    generations = ceremonies.map { |ceremony| ceremony.reload.email_otp_context.fetch("generation") }
    paused = Queue.new
    proceed = Queue.new
    ready = Queue.new
    start = Queue.new
    first = second = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless Thread.current == first
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_auth_ceremony_sessions"/i)

        paused << true
        proceed.pop
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      first =
        Thread.new do
          start.pop
          resend(ceremonies.first, states.first)
        end
      start << true
      Timeout.timeout(10) { paused.pop }
      second =
        Thread.new do
          EmailOccurrence.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()").to_i
            resend(ceremonies.last, states.last)
          end
        end
      pid = Timeout.timeout(10) { ready.pop }
      Timeout.timeout(10) do
        loop do
          blocked =
            EmailOccurrence.uncached do
              EmailOccurrence.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
            end
          break if blocked

          Thread.pass
        end
      end
      proceed << true

      assert_equal :ok, Timeout.timeout(10) { first.value }.status
      assert_equal :too_many_requests, Timeout.timeout(10) { second.value }.status
      assert_not_equal generations.first, ceremonies.first.reload.email_otp_context.fetch("generation")
      assert_equal generations.last, ceremonies.last.reload.email_otp_context.fetch("generation")
      assert_match(/issued=[0-9]+(?: retry_after=[0-9]+)?\z/, EmailOccurrence.find_by!(body:).memo)
    end
  ensure
    proceed << true if proceed
    [first, second].compact.each { |thread| thread.join(10) }
    EmailOccurrence.where(body:).delete_all if body
    ceremonies&.each(&:delete)
    admissions&.each do |admission|
      ClientAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id).delete_all
      admission.transaction.delete
    end
  end

  test "occurrence failure after OTP commit preserves the new generation" do
    address = "resend-write-failure-#{SecureRandom.hex(8)}@example.test"
    body = OccurrenceHmac.digest(kind: :email, body: address)
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", authorization_transaction_ref: admission.transaction.transaction_id,
    )
    ceremony.issue_email_otp!(contact: nil, destination: address)
    generation = ceremony.reload.email_otp_context.fetch("generation")
    state = SignInOtpResendState.issue(
      kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact: nil,
    )

    result =
      Rails.error.stub(:report, ->(*, **) { }) do
        EmailOccurrence.stub(:create!, ->(**) { raise ActiveRecord::ConnectionNotEstablished }) do
          resend(ceremony, state)
        end
      end

    assert_equal :service_unavailable, result.status
    assert_not_equal generation, ClientAuthCeremonySession.find(ceremony.id).email_otp_context.fetch("generation")
    assert_nil EmailOccurrence.find_by(body:)
  ensure
    EmailOccurrence.where(body:).delete_all if body
    ceremony&.delete
    if admission
      ClientAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id).delete_all
      admission.transaction.delete
    end
  end

  test "an Auth commit failure before issuance preserves the existing challenge and prevents delivery" do
    address = "resend-auth-commit-failure-#{SecureRandom.hex(8)}@example.test"
    body = OccurrenceHmac.digest(kind: :email, body: address)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    contact = owner.client_emails.create!(address:, confirm_policy: "1").tap(&:finalize_binding!)
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", authorization_transaction_ref: admission.transaction.transaction_id,
    )
    ceremony.issue_email_otp!(contact:, destination: address)
    original_context = ceremony.reload.email_otp_context.deep_dup
    state = SignInOtpResendState.issue(
      kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact:,
    )
    auth_connection = ClientAuthCeremonySession.lease_connection
    adapter = Minitest::Mock.new
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected Auth transaction commit failure" }
    queued_otp_jobs_before =
      ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    result = nil
    Rails.error.stub(:report, ->(*, **) { }) do
      OtpAdapter.stub(:for, adapter) do
        auth_connection.stub(:commit_db_transaction, failed_commit) do
          result = SignInOtpResender.new(
            kind: :email, state:, surface: :app,
            browser_binding: ceremony.sid_digest, ceremony:,
          ).call
        end
      end
    end

    assert_equal :service_unavailable, result.status
    assert_equal original_context, ClientAuthCeremonySession.find(ceremony.id).email_otp_context
    assert_nil EmailOccurrence.find_by(body:)
    queued_otp_jobs_after =
      ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_equal queued_otp_jobs_before, queued_otp_jobs_after
    adapter.verify
  ensure
    EmailOccurrence.where(body:).delete_all if body
    ceremony&.delete
    if admission
      ClientAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id).delete_all
      admission.transaction.delete
    end
    contact&.delete
    owner&.delete
  end

  test "a lost occurrence commit acknowledgement does not start delivery" do
    address = "resend-unknown-commit-#{SecureRandom.hex(8)}@example.test"
    body = OccurrenceHmac.digest(kind: :email, body: address)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    contact = owner.client_emails.create!(address:, confirm_policy: "1").tap(&:finalize_binding!)
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", authorization_transaction_ref: admission.transaction.transaction_id,
    )
    ceremony.issue_email_otp!(contact:, destination: address)
    generation = ceremony.reload.email_otp_context.fetch("generation")
    state = SignInOtpResendState.issue(
      kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact:,
    )
    connection = EmailOccurrence.lease_connection
    commit = connection.method(:commit_db_transaction)
    lose_ack =
      lambda do
        commit.call
        connection.disconnect!
        raise PG::ConnectionBad, "injected lost commit acknowledgement"
      end
    adapter = Minitest::Mock.new

    result =
      Rails.error.stub(:report, ->(*, **) { }) do
        OtpAdapter.stub(:for, adapter) do
          connection.stub(:commit_db_transaction, lose_ack) do
            # The already committed and disconnected backend cannot roll back.
            connection.stub(:rollback_db_transaction, -> { }) { resend(ceremony, state) }
          end
        end
      end

    assert_equal :service_unavailable, result.status
    assert_not_equal generation, ClientAuthCeremonySession.find(ceremony.id).email_otp_context.fetch("generation")
    assert EmailOccurrence.exists?(body:)
    adapter.verify
  ensure
    EmailOccurrence.where(body:).delete_all if body
    ceremony&.delete
    if admission
      ClientAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id).delete_all
      admission.transaction.delete
    end
    contact&.delete
    owner&.delete
  end

  test "a held destination lock times out without changing the challenge" do
    address = "resend-lock-timeout-#{SecureRandom.hex(8)}@example.test"
    body = OccurrenceHmac.digest(kind: :email, body: address)
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", authorization_transaction_ref: admission.transaction.transaction_id,
    )
    ceremony.issue_email_otp!(contact: nil, destination: address)
    original = ceremony.reload.email_otp_context.deep_dup
    state = SignInOtpResendState.issue(
      kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact: nil,
    )
    ready = Queue.new
    worker = nil

    EmailOccurrence.transaction do
      key = Digest::SHA256.digest("sign_in:email_otp_resend:#{body}").unpack1("q>")
      EmailOccurrence.lease_connection.execute("SELECT pg_advisory_xact_lock(#{key.to_i})")
      Rails.error.stub(:report, ->(*, **) { }) do
        worker =
          Thread.new do
            EmailOccurrence.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()").to_i
              resend(ceremony, state)
            end
          end
        pid = Timeout.timeout(10) { ready.pop }
        Timeout.timeout(10) do
          loop do
            blocked =
              EmailOccurrence.uncached do
                EmailOccurrence.lease_connection.select_value(
                  "SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0",
                )
              end
            break if blocked

            Thread.pass
          end
        end

        assert_equal :service_unavailable, Timeout.timeout(10) { worker.value }.status
      end
    end

    assert_withheld { original == ceremony.reload.email_otp_context }
    assert_nil EmailOccurrence.find_by(body:)
  ensure
    worker&.join(10)
    EmailOccurrence.where(body:).delete_all if body
    ceremony&.delete
    if admission
      ClientAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id).delete_all
      admission.transaction.delete
    end
  end

  private

  def resend(ceremony, state)
    current = ClientAuthCeremonySession.find(ceremony.id)
    SignInOtpResender.new(
      kind: :email, state:, surface: :app, browser_binding: current.sid_digest, ceremony: current,
    ).call
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end
end
