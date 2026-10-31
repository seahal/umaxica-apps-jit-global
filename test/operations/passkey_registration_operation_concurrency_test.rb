# frozen_string_literal: true

require "test_helper"
require "timeout"

# The ten-Passkey limit is a count check, so two registrations racing for the last place must be
# serialized by the owner lock the operation takes. Independent connections commit for real.
class PasskeyRegistrationOperationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    9.times do |index|
      @client.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "existing-key-#{index}")
    end
  end

  teardown do
    ClientPasskeyAuditOutbox.where(actor_ref: @client.public_id).delete_all
    ClientPasskey.where(user_id: @client.id).delete_all
    Client.where(id: @client.id).delete_all
  end

  test "two registrations racing for the tenth place commit exactly one" do
    ready = Queue.new
    release = Queue.new
    threads =
      2.times.map do |index|
        Thread.new do
          ready << true
          release.pop
          AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
            PasskeyRegistrationOperation.call!(
              actor: Client.find(@client.id),
              passkey_class: ClientPasskey,
              attributes: { webauthn_id: SecureRandom.uuid, public_key: "racing-key-#{index}" },
              audit: { event_type: "passkey.registered.settings", surface: "app", operation_ref: SecureRandom.uuid },
            )
          end
        rescue ActiveRecord::RecordInvalid => e
          e
        end
      end

    2.times { ready.pop }
    2.times { release << true }
    results = threads.map(&:value)

    assert_equal 1, results.count { |result| result.is_a?(ClientPasskey) }, results.inspect
    assert_equal 1, results.grep(ActiveRecord::RecordInvalid).size, results.inspect
    assert_equal 10, ClientPasskey.where(user_id: @client.id).count
  ensure
    2.times { release << true } if release
    threads&.each(&:join)
  end

  test "two ORG registrations racing for the tenth place commit exactly one" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    9.times do |index|
      operator.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "existing-org-key-#{index}")
    end
    ready = Queue.new
    release = Queue.new
    threads =
      2.times.map do |index|
        Thread.new do
          ready << true
          release.pop
          OrgZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
            PasskeyRegistrationOperation.call!(
              actor: Operator.find(operator.id), passkey_class: OperatorPasskey,
              attributes: { webauthn_id: SecureRandom.uuid, public_key: "racing-org-key-#{index}" },
              audit: { event_type: "passkey.registered.settings", surface: "org", operation_ref: SecureRandom.uuid },
            )
          end
        rescue ActiveRecord::RecordInvalid => e
          e
        end
      end

    2.times { ready.pop }
    2.times { release << true }
    results = threads.map(&:value)

    assert_equal 1, results.count { |result| result.is_a?(OperatorPasskey) }, results.inspect
    assert_equal 1, results.grep(ActiveRecord::RecordInvalid).size, results.inspect
    assert_equal 10, OperatorPasskey.where(staff_id: operator.id).count
    assert_equal 1, OperatorPasskeyAuditOutbox.where(actor_ref: operator.public_id).count
  ensure
    2.times { release << true } if release
    threads&.each(&:join)
    OperatorPasskeyAuditOutbox.where(actor_ref: operator.public_id).delete_all if operator
    OperatorPasskey.where(staff_id: operator.id).delete_all if operator
    Operator.where(id: operator.id).delete_all if operator
  end

  test "registration rechecks owner status after a concurrent stop commits" do
    ready = Queue.new
    proceed = Queue.new
    worker =
      Thread.new do
        AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
          actor = Client.find(@client.id)
          ready << connection.select_value("SELECT pg_backend_pid()").to_i
          proceed.pop
          PasskeyRegistrationOperation.call!(
            actor: actor, passkey_class: ClientPasskey,
            attributes: { webauthn_id: SecureRandom.uuid, public_key: "stopped-owner-key" },
            audit: { event_type: "passkey.registered.settings", surface: "app" },
          )
        end
      rescue ArgumentError => e
        e
      end
    backend_pid = Timeout.timeout(10) { ready.pop }
    before_audits = ClientPasskeyAuditOutbox.where(actor_ref: @client.public_id).count

    Client.transaction do
      @client.lock!
      @client.update!(status_id: ClientStatus::RESERVED)
      proceed << true
      Timeout.timeout(10) do
        loop do
          waiting =
            Client.lease_connection.uncached do
              Client.lease_connection.select_value(
                "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(backend_pid)}",
              )
            end
          break if waiting == "Lock"

          sleep 0.01
        end
      end
    end

    result = Timeout.timeout(10) { worker.value }

    assert_instance_of ArgumentError, result
    assert_equal "Passkey registration owner is unavailable", result.message
    assert_equal 9, ClientPasskey.where(user_id: @client.id).count
    assert_equal before_audits, ClientPasskeyAuditOutbox.where(actor_ref: @client.public_id).count
  ensure
    proceed << true if proceed
    worker&.join
  end

  test "ORG registration rechecks owner status after a concurrent stop commits" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    ready = Queue.new
    proceed = Queue.new
    worker =
      Thread.new do
        OrgZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
          actor = Operator.find(operator.id)
          ready << connection.select_value("SELECT pg_backend_pid()").to_i
          proceed.pop
          PasskeyRegistrationOperation.call!(
            actor: actor, passkey_class: OperatorPasskey,
            attributes: { webauthn_id: SecureRandom.uuid, public_key: "stopped-operator-key" },
            audit: { event_type: "passkey.registered.settings", surface: "org" },
          )
        end
      rescue ArgumentError => e
        e
      end
    backend_pid = Timeout.timeout(10) { ready.pop }
    before_audits = OperatorPasskeyAuditOutbox.where(actor_ref: operator.public_id).count

    Operator.transaction do
      operator.lock!
      operator.update!(status_id: OperatorStatus::RESERVED)
      proceed << true
      Timeout.timeout(10) do
        loop do
          waiting =
            Operator.lease_connection.uncached do
              Operator.lease_connection.select_value(
                "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(backend_pid)}",
              )
            end
          break if waiting == "Lock"

          sleep 0.01
        end
      end
    end

    result = Timeout.timeout(10) { worker.value }

    assert_instance_of ArgumentError, result
    assert_equal "Passkey registration owner is unavailable", result.message
    assert_equal 0, OperatorPasskey.where(staff_id: operator.id).count
    assert_equal before_audits, OperatorPasskeyAuditOutbox.where(actor_ref: operator.public_id).count
  ensure
    proceed << true if proceed
    worker&.join
    OperatorPasskeyAuditOutbox.where(actor_ref: operator.public_id).delete_all if operator
    OperatorPasskey.where(staff_id: operator.id).delete_all if operator
    Operator.where(id: operator.id).delete_all if operator
  end
end
