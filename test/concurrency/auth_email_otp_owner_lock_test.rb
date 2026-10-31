# frozen_string_literal: true

require "test_helper"
require "timeout"

class AuthEmailOtpOwnerLockTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "Email release waits for issuance and prevents the issued code from verifying" do
    owner = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )
    email = owner.client_emails.create!(
      address: "auth-issue-#{SecureRandom.hex(8)}@example.test", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: OidcTestEntry::CODE_CHALLENGE,
        code_challenge_method: "S256",
      },
    ).transaction
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", authorization_transaction_ref: parent.transaction_id,
    )
    issued = Queue.new
    proceed = Queue.new
    release_ready = Queue.new
    issuer = release = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_auth_ceremony_sessions"/i)

        issued << true
        proceed.pop
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      issuer =
        Thread.new do
          ClientAuthCeremonySession.find(ceremony.id).issue_email_otp!(
            contact: ClientEmail.find(email.id), destination: email.address,
          )
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      Timeout.timeout(10) { issued.pop }
      release =
        Thread.new do
          ClientEmail.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            release_ready << connection.select_value("SELECT pg_backend_pid()").to_i
            ClientEmail.find(email.id).release_binding!
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      pid = Timeout.timeout(10) { release_ready.pop }
      Timeout.timeout(10) do
        loop do
          waiting =
            ClientEmail.uncached do
              ClientEmail.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
            end
          break if waiting

          Thread.pass
        end
      end
      proceed << true
      code = Timeout.timeout(10) { issuer.value }

      assert_predicate code, :present?
      assert Timeout.timeout(10) { release.value }
      assert_not ceremony.reload.verify_email_otp!(code: code).success?
    end
  ensure
    proceed << true if proceed
    [issuer, release].compact.each do |thread|
      begin
        thread.join(10)
      rescue StandardError
        # Preserve the test failure while still removing its synthetic records.
      end
    end
    ceremony&.delete
    parent&.delete
    email&.delete
    owner&.delete
  end

  test "cooldown committed while issuance waits is checked before changing Auth" do
    owner = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )
    email = owner.client_emails.create!(
      address: "auth-issue-#{SecureRandom.hex(8)}@example.test", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: OidcTestEntry::CODE_CHALLENGE,
        code_challenge_method: "S256",
      },
    ).transaction
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", authorization_transaction_ref: parent.transaction_id,
    )
    original = ceremony.reload.email_otp_context.deep_dup
    ready = Queue.new
    issuer = nil
    owner.with_lock do
      email.update!(otp_last_sent_at: ClientEmail.database_now)
      holder_pid = Client.lease_connection.select_value("SELECT pg_backend_pid()").to_i
      issuer =
        Thread.new do
          Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()").to_i
            AuthEmailSignInOtpIssuer.call(
              ceremony: ClientAuthCeremonySession.find(ceremony.id),
              contact: ClientEmail.find(email.id), destination: email.address,
            )
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      issuer_pid = Timeout.timeout(10) { ready.pop }
      Timeout.timeout(10) do
        loop do
          waiting =
            Client.uncached do
              Client.lease_connection.select_value(
                "SELECT #{Integer(holder_pid)} = ANY(pg_blocking_pids(#{Integer(issuer_pid)}))",
              )
            end
          break if waiting

          Thread.pass
        end
      end

      ClientOidcAuthorizationTransaction.transaction do
        assert ClientOidcAuthorizationTransaction.lock("FOR UPDATE NOWAIT").find(parent.id)
      end
    end

    assert_raises(AuthEmailSignInOtpIssuer::Cooldown) { Timeout.timeout(10) { issuer.value } }
    unchanged = original == ceremony.reload.email_otp_context

    assert unchanged, "cooldown refusal must retain the challenge"
  ensure
    [issuer].compact.each do |thread|
      begin
        thread.join(10)
      rescue StandardError
        # Preserve the test failure while still removing its synthetic records.
      end
    end
    ceremony&.delete
    parent&.delete
    email&.delete
    owner&.delete
  end

  test "Email cancellation waits for an in-flight delivery and prevents code verification" do
    owner = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )
    email = owner.client_emails.create!(
      address: "auth-delivery-#{SecureRandom.hex(8)}@example.test", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: OidcTestEntry::CODE_CHALLENGE,
        code_challenge_method: "S256",
      },
    ).transaction
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", authorization_transaction_ref: parent.transaction_id,
    )
    code = ceremony.issue_email_otp!(contact: email, destination: email.address)
    generation = ceremony.reload.email_otp_context.fetch("generation")
    started = Queue.new
    proceed = Queue.new
    cancellation_ready = Queue.new
    delivery = cancellation = nil

    delivery =
      Thread.new do
        ClientAuthCeremonySession.find(ceremony.id).with_email_otp_delivery!(
          generation: generation, code: code, destination: email.address,
        ) do
          started << ClientAuthCeremonySession.lease_connection.select_value("SELECT pg_backend_pid()").to_i
          proceed.pop
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    delivery_pid = Timeout.timeout(10) { started.pop }
    cancellation =
      Thread.new do
        ClientAuthCeremonySession.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
          cancellation_ready << connection.select_value("SELECT pg_backend_pid()").to_i
          ClientAuthCeremonySession.find(ceremony.id).cancel_email_otp_challenge!
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    pid = Timeout.timeout(10) { cancellation_ready.pop }
    Timeout.timeout(10) do
      loop do
        waiting =
          ClientAuthCeremonySession.uncached do
            ClientAuthCeremonySession.lease_connection.select_value(
              "SELECT #{Integer(delivery_pid)} = ANY(pg_blocking_pids(#{Integer(pid)}))",
            )
          end
        break if waiting

        Thread.pass
      end
    end
    proceed << true

    assert Timeout.timeout(10) { delivery.value }
    assert Timeout.timeout(10) { cancellation.value }
    assert_not ceremony.reload.verify_email_otp!(code: code).success?
    assert_predicate ceremony.reload.email_otp_context.fetch("cancelled_at"), :present?
  ensure
    proceed << true if proceed
    [delivery, cancellation].compact.each do |thread|
      begin
        thread.join(10)
      rescue StandardError
        # Preserve the test failure while still removing its synthetic records.
      end
    end
    ceremony&.delete
    parent&.delete
    email&.delete
    owner&.delete
  end

  races = %i(release replacement real_replacement).product(%i(verification delivery)) +
    [[:release, :issuance]] + %i(release replacement real_replacement cancellation).product([:reissuance])
  races.each do |change, operation|
    test "Email #{operation} refuses when #{change} wins while it waits for the owner" do
      owner = Client.create!(
        id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      )
      email = owner.client_emails.create!(
        address: "auth-lock-#{SecureRandom.hex(8)}@example.test", user_email_status_id: ClientEmailStatus::VERIFIED,
      )
      email.finalize_binding!
      if change == :real_replacement
        replacement_owner = Client.create!(
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
          security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
        )
        replacement_email = replacement_owner.client_emails.create!(
          address: "auth-replacement-#{SecureRandom.hex(8)}@example.test",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        )
        replacement_email.finalize_binding!
      end
      client = OidcClientRegistry.find!("core-app-jp")
      parent = OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app", intent: "sign_in", params: {
          client_id: client.client_id,
          response_type: "code",
          scope: "openid profile",
          redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
          state: SecureRandom.hex(8),
          nonce: SecureRandom.hex(8),
          code_challenge: OidcTestEntry::CODE_CHALLENGE,
          code_challenge_method: "S256",
        },
      ).transaction
      ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: parent.transaction_id,
      )
      code = ceremony.issue_email_otp!(contact: email, destination: email.address)
      generation = ceremony.reload.email_otp_context.fetch("generation")
      ready = Queue.new
      deliveries = Queue.new
      worker = nil
      replacement_context = nil

      owner.with_lock do
        worker =
          Thread.new do
            Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()").to_i
              current = ClientAuthCeremonySession.find(ceremony.id)
              if operation == :verification
                current.verify_email_otp!(code: code)
              elsif operation == :delivery
                current.with_email_otp_delivery!(generation: generation, code: code, destination: email.address) do
                  deliveries << true
                end
              elsif operation == :reissuance
                current.issue_email_otp!(
                  contact: ClientEmail.find(email.id), destination: email.address, expected_generation: generation,
                )
              else
                current.issue_email_otp!(contact: ClientEmail.find(email.id), destination: email.address)
              end
            end
          rescue AuthCeremonySession::InvalidTransition => e
            e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        pid = Timeout.timeout(10) { ready.pop }
        Timeout.timeout(10) do
          loop do
            waiting =
              Client.uncached do
                Client.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
              end
            break if waiting

            Thread.pass
          end
        end

        assert ClientOidcAuthorizationTransaction.lock("FOR UPDATE NOWAIT").find(parent.id)
        if change == :release
          email.release_binding!
        elsif change == :replacement
          ceremony.issue_email_otp!(contact: nil, destination: "unknown-#{SecureRandom.hex(8)}@example.test")
        elsif change == :cancellation
          ceremony.cancel_email_otp_challenge!
        else
          ceremony.issue_email_otp!(contact: replacement_email, destination: replacement_email.address)
        end
        replacement_context = ceremony.reload.email_otp_context.deep_dup
      end

      result = Timeout.timeout(10) { worker.value }

      if operation == :verification
        assert_not result.success?
        assert_equal :binding_unavailable, result.status
      elsif operation == :delivery
        assert_not result
        assert_predicate deliveries, :empty?
      elsif operation == :reissuance
        assert_same false, result
      else
        assert_instance_of AuthCeremonySession::InvalidTransition, result
      end

      assert_nil ceremony.reload.email_otp_context.fetch("verified_at")
      assert_equal replacement_context, ceremony.email_otp_context
    ensure
      begin
        worker&.join(10)
      rescue StandardError
        # Preserve the test failure while still removing its synthetic records.
      end
      ceremony&.delete
      parent&.delete
      email&.delete
      owner&.delete
      replacement_email&.delete
      replacement_owner&.delete
    end
  end
end
