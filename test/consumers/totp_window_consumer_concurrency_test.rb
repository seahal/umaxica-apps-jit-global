# typed: false
# frozen_string_literal: true

require "test_helper"

# These tests use committed rows and separate connections. A single connection or transactional
# fixture cannot prove that the terminal TOTP transition is serialized in PostgreSQL.
# RuboCop's thread rule is disabled here because independent worker threads are the behavior under
# test; the connections are checked out explicitly from the application pool.
# rubocop:disable ThreadSafety/NewThread
class TotpWindowConsumerConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    ClientStatus.ensure_defaults! if ClientStatus.respond_to?(:ensure_defaults!)
    ClientTotpCredentialStatus.ensure_defaults! if ClientTotpCredentialStatus.respond_to?(:ensure_defaults!)
    @user = Client.create!(mfa_level_enabled: true)
    @credential = ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
      otp_attempts_count: 99,
    )
    @now = Time.current.floor
  end

  teardown do
    next unless @user

    ClientTotpCredential.where(user_id: @user.id).delete_all
    Client.where(id: @user.id).delete_all
  end

  test "concurrent failures at 99 revoke once and never exceed 100" do
    token = wrong_code
    ActiveRecord::Base.connection_handler.clear_active_connections!

    results =
      concurrently(3) do
        TotpWindowConsumer.call(credentials: active_credentials, token: token, now: @now)
      end

    errors = results.grep(Exception)

    assert_empty errors, errors.map { |error| "#{error.class}: #{error.message}" }.join("\n")
    assert results.none?(&:accepted?)

    @credential.reload

    assert_equal 100, @credential.otp_attempts_count
    assert_equal ClientTotpCredentialStatus::REVOKED, @credential.user_identity_totp_credential_status_id
  end

  test "a failure that commits while another transaction holds the row is not lost" do
    target = @credential
    locked = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!

    holder =
      Thread.new do
        AppZenithRecord.connection_pool.with_connection do
          ClientTotpCredential.transaction do
            row = ClientTotpCredential.lock.find(target.id)
            locked << true
            sleep 0.5
            row.record_totp_failure!
          end
        end
      end

    locked.pop
    result =
      AppZenithRecord.connection_pool.with_connection do
        TotpWindowConsumer.call(credentials: active_credentials, token: wrong_code, now: @now)
      end
    holder.join

    assert_not_predicate result, :accepted?
    assert_equal 100, target.reload.otp_attempts_count
    assert_equal ClientTotpCredentialStatus::REVOKED, target.user_identity_totp_credential_status_id
  end

  test "a correct code cannot revive a credential revoked before its locked verification" do
    code = ROTP::TOTP.new(@credential.private_key).at(@now.to_i)
    locked = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!

    holder =
      Thread.new do
        AppZenithRecord.connection_pool.with_connection do
          ClientTotpCredential.transaction do
            row = ClientTotpCredential.lock.find(@credential.id)
            locked << true
            release.pop
            row.update!(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::REVOKED)
          end
        end
      end

    locked.pop
    result_thread =
      Thread.new do
        AppZenithRecord.connection_pool.with_connection do
          TotpWindowConsumer.call(credentials: active_credentials, token: code, now: @now)
        end
      end

    sleep 0.1
    release << true
    result = result_thread.value
    holder.join

    assert_not_predicate result, :accepted?
    assert_equal ClientTotpCredentialStatus::REVOKED, @credential.reload.user_identity_totp_credential_status_id
    assert_equal 99, @credential.otp_attempts_count
  end

  private

  def active_credentials
    ClientTotpCredential
      .where(user_id: @user.id, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
  end

  def wrong_code
    valid = [-30, 0, 30].map { |offset| ROTP::TOTP.new(@credential.private_key).at(@now.to_i + offset) }
    ("000000".."999999").find { |candidate| valid.exclude?(candidate) }
  end

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
end
# rubocop:enable ThreadSafety/NewThread
