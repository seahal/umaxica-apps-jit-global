# typed: false
# frozen_string_literal: true

require "test_helper"

# Enrollment uses the Client row as the cross-database coordination lock. This test intentionally
# uses independent connections so a Ruby count check cannot make the race pass by accident.
# RuboCop's thread rule is disabled here because independent worker threads are the behavior under
# test; the connections are checked out explicitly from the application pool.
# rubocop:disable ThreadSafety/NewThread
class ClientTotpCredentialEnrollmentConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    ClientStatus.ensure_defaults! if ClientStatus.respond_to?(:ensure_defaults!)
    ClientTotpCredentialStatus.ensure_defaults! if ClientTotpCredentialStatus.respond_to?(:ensure_defaults!)
    @user = Client.create!(status_id: ClientStatus::NOTHING)
  end

  teardown do
    ClientTotpCredential.where(user_id: @user.id).delete_all
    Client.where(id: @user.id).delete_all
  end

  test "concurrent enrollments cannot exceed the two slot-consuming credentials" do
    results =
      concurrently(3) do
        user = Client.find(@user.id)
        ClientTotpCredential.create_for_user!(
          user: user,
          private_key: ROTP::Base32.random_base32,
          last_otp_at: Time.current,
          user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        )
      end

    errors = results.grep(ClientTotpCredential::SlotLimitExceeded)

    assert_equal 1, errors.length
    assert_equal ClientTotpCredential::MAX_TOTP_SLOTS,
                 ClientTotpCredential.slot_consuming.where(user_id: @user.id).count
  end

  private

  def concurrently(count)
    ready = Queue.new
    release = Queue.new
    threads =
      Array.new(count) do
        Thread.new do
          ready << true
          release.pop
          Client.connection_pool.with_connection { yield }
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
