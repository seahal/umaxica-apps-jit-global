# frozen_string_literal: true

require "test_helper"
require "timeout"

class SocialAuthLinkConcurrencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  uses_transaction :test_concurrent_clients_for_one_social_subject_keep_one_owner
  uses_transaction :test_concurrent_providers_for_one_client_keep_one_effective_binding

  test "concurrent clients for one social subject keep one owner" do
    clients = 2.times.map { Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL) }
    subject = SecureRandom.uuid
    principals = 2.times.map { verified_principal(provider: "google", subject: subject) }

    results, backends = race_link_attempts(clients.zip(principals))

    assert_equal 2, backends.uniq.length
    assert_equal 1, results.count(:linked)
    assert_equal 1, results.count(:conflict)
    assert_equal 1, ClientExternalIdentity.effective_binding.where(provider: "google", subject: subject).count
    assert_equal 1, ClientSocialAuditOutbox.where(owner_ref: clients.map(&:public_id), event_name: "linked").count
  ensure
    remove_race_records(clients)
  end

  test "concurrent providers for one client keep one effective binding" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    clients = [client]
    principals = [
      verified_principal(provider: "google", subject: SecureRandom.uuid),
      verified_principal(provider: "apple", subject: SecureRandom.uuid),
    ]

    results, backends = race_link_attempts([[client, principals.first], [client, principals.last]])

    assert_equal 2, backends.uniq.length
    assert_equal 1, results.count(:linked)
    assert_equal 1, results.count(:conflict)
    assert_equal 1, ClientExternalIdentity.effective_binding.where(client_id: client.id).count
    assert_equal 1, ClientSocialAuditOutbox.where(owner_ref: client.public_id, event_name: "linked").count
  ensure
    remove_race_records(clients)
  end

  private

  def verified_principal(provider:, subject:)
    issuer = (provider == "google") ? "https://accounts.google.com" : "https://appleid.apple.com"
    ExternalAuthentication::VerifiedPrincipal.new(
      provider: provider, subject: subject, issuer: issuer, audience: "provider-test-client",
      verified_at: Time.current, verification_authority: "provider-fixture",
    )
  end

  def race_link_attempts(attempts)
    ready = Queue.new
    release = Queue.new
    started_at = Time.current
    ActiveRecord::Base.connection_handler.clear_active_connections!
    threads =
      attempts.map do |client, principal|
        Thread.new do
          ClientExternalIdentity.connection_pool.with_connection do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            release.pop
            owner = Client.find(client.id)
            ExternalAuthenticationLinkUseCase.call(
              principal: principal, credential_candidate: nil, user: owner,
              ceremony_started_at: started_at,
            ).status
          rescue SocialAuth::ConflictError
            :conflict
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    backends = Timeout.timeout(10) { attempts.map { ready.pop } }
    attempts.length.times { release << true }
    results = Timeout.timeout(15) { threads.map(&:value) }
    [results, backends]
  ensure
    attempts.length.times { release << true } if release
    threads&.each { |thread| thread.join(1) || thread.kill }
  end

  def remove_race_records(clients)
    return if clients.blank?

    ClientSocialAuditOutbox.where(owner_ref: clients.map(&:public_id)).delete_all
    ClientExternalIdentity.where(client_id: clients.map(&:id)).delete_all
    Client.where(id: clients.map(&:id)).delete_all
  end
end
