# typed: false
# frozen_string_literal: true

require "test_helper"

# Concurrent TOTP failures against one account must each be counted. The lockout is a
# PostgreSQL row-locked update, so this needs real separate connections and committed rows:
# transactional tests are off and the rows are removed in teardown.
class TotpWindowConsumerConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  ATTEMPTS = 10

  setup do
    ClientStatus.ensure_defaults! if ClientStatus.respond_to?(:ensure_defaults!)
    ClientTotpCredentialStatus.ensure_defaults! if ClientTotpCredentialStatus.respond_to?(:ensure_defaults!)
    @user = Client.create!(mfa_level_enabled: true)
    @credentials =
      Array.new(2) do
        ClientTotpCredential.create!(
          user: @user,
          private_key: ROTP::Base32.random_base32,
          user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
          title: "totp",
        )
      end
    @now = Time.current.floor
  end

  teardown do
    next unless @user

    ClientTotpCredential.where(user_id: @user.id).delete_all
    Client.where(id: @user.id).delete_all
  end

  test "concurrent failures are all recorded and lock the account exactly at the threshold" do
    token = wrong_code
    ActiveRecord::Base.connection_handler.clear_active_connections!

    results =
      concurrently(ATTEMPTS) do
        TotpWindowConsumer.call(credentials: active_credentials, token: token, now: @now)
      end

    errors = results.grep(Exception)

    assert_empty errors, errors.map { |error| "#{error.class}: #{error.message}" }.join("\n")
    assert_equal ATTEMPTS, results.count { |result| result.status == :mismatch }
    @credentials.each do |credential|
      credential.reload

      assert_equal ATTEMPTS, credential.otp_attempts_count
      assert_equal @now + ClientTotpCredential::TOTP_LOCKOUT_DURATION, credential.totp_locked_until(@now)
    end
  end

  # Deterministic interleaving: another transaction holds the credential row and records a
  # failure. The consumer must wait for that commit and count on top of it; reading the row
  # before the commit would write back a stale count and lose the other failure.
  test "a failure recorded by a concurrent transaction is not overwritten" do
    token = wrong_code
    target = @credentials.first
    ActiveRecord::Base.connection_handler.clear_active_connections!

    locked = Queue.new
    # rubocop:disable ThreadSafety/NewThread
    holder =
      Thread.new do
        AppZenithRecord.connection_pool.with_connection do
          ClientTotpCredential.transaction do
            row = ClientTotpCredential.lock.find(target.id)
            locked << true
            sleep 0.5
            row.record_totp_failure!(@now)
          end
        end
      end
    # rubocop:enable ThreadSafety/NewThread

    locked.pop
    result =
      AppZenithRecord.connection_pool.with_connection do
        TotpWindowConsumer.call(credentials: active_credentials, token: token, now: @now)
      end
    holder.join

    assert_equal :mismatch, result.status
    assert_equal 2, target.reload.otp_attempts_count
  end

  private

  def active_credentials
    ClientTotpCredential
      .where(user_id: @user.id, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
      .order(created_at: :desc)
  end

  def wrong_code
    valid =
      @credentials.flat_map do |credential|
        totp = ROTP::TOTP.new(credential.private_key)
        [-30, 0, 30].map { |offset| totp.at(@now.to_i + offset) }
      end
    ("000000".."999999").find { |candidate| valid.exclude?(candidate) }
  end

  # The test pool has two connections, so threads wait at the barrier without holding one and
  # then compete for the pool; the row lock is what serializes them, not the pool.
  # rubocop:disable ThreadSafety/NewThread
  def concurrently(count)
    ready = Queue.new
    release = Queue.new
    threads =
      Array.new(count) do
        Thread.new do
          ready << true
          release.pop
          AppZenithRecord.connection_pool.with_connection { yield }
        rescue StandardError => e
          e
        end
      end

    count.times { ready.pop }
    count.times { release << true }
    threads.map(&:value)
  end
  # rubocop:enable ThreadSafety/NewThread
end
