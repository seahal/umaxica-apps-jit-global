# frozen_string_literal: true

require "test_helper"

# The ten-Passkey limit is a count check, so two registrations racing for the last place must be
# serialized by the owner lock the operation takes. Independent connections commit for real.
class PasskeyRegistrationOperationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @client = Client.create!
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
end
