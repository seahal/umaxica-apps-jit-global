# frozen_string_literal: true

require "test_helper"
require "timeout"

class AuthAdmissionBindingConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(app com org).each do |surface|
    test "#{surface} simultaneous exact Base confirmations converge on one immutable proof without admission" do
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = BaseAuthAdmissionCoordinator.admission_binding_model(surface)
      binding = model.find_by!(entry_ref: issuance.reference)
      continuity = model.auth_admission_session_class.issue!.first
      binding.attach_auth_session!(auth_session: continuity, confirmation_ref: SecureRandom.uuid)
      original_facts = binding.attributes.slice(
        "entry_ref", "confirmation_ref", "auth_ceremony_session_id", "base_browser_digest", "expires_at",
      )
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      workers =
        Array.new(2) do
          Concurrent::Future.execute do
            model.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              candidate = model.find(binding.id)
              BaseAuthAdmissionCoordinator.with_admission_binding_lock!(candidate) do |locked|
                locked.confirm_base!(base_token: nil, browser_digest: original_facts.fetch("base_browser_digest"))
                locked.base_confirmed_at
              end
            end
          ensure
            # Leases taken on this pooled thread outlive the future unless released here.
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      backends = Timeout.timeout(10) { Array.new(2) { ready.pop } }
      2.times { release << true }
      results = Timeout.timeout(10) { workers.map(&:value!) }

      assert_equal 2, backends.uniq.length
      assert_equal [binding.reload.base_confirmed_at], results.uniq
      assert_not_nil binding.base_confirmed_at
      assert_equal original_facts, binding.attributes.slice(*original_facts.keys)
      assert_nil binding.redeemed_at
      assert_nil binding.admitted_auth_ceremony_session_id
      assert_predicate continuity.reload, :active?
      assert_not_predicate continuity, :admitted?
      assert_predicate issuance.transaction.reload, :sign_in_primary_pending?
    ensure
      2.times { release << true } if release
      workers&.each { |worker| worker.wait(10) }
      binding&.delete
      issuance&.transaction&.delete
      continuity&.delete
    end

    test "#{surface} concurrent confirmed redemption rotates once and preserves the other tab's parent" do
      first = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface:, intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
      )
      sibling = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface:, intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
      )
      model = BaseAuthAdmissionCoordinator.admission_binding_model(surface)
      auth_model = model.auth_admission_session_class
      bindings = [first, sibling].map { |issued| model.find_by!(entry_ref: issued.reference) }
      original, raw_sid = auth_model.issue!
      bindings.each do |binding|
        binding.attach_auth_session!(auth_session: original, confirmation_ref: SecureRandom.uuid)
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
      end
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      workers =
        Array.new(2) do
          Concurrent::Future.execute do
            model.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              BaseAuthAdmissionCoordinator.with_admission_binding_lock!(model.find(bindings.first.id)) do |locked|
                BaseAuthAdmissionCoordinator.consume_entry_reference!(
                  reference: first.reference, surface:, expected_intent: "sign_in",
                  binding: locked, raw_auth_sid: raw_sid,
                )
                admitted, = auth_model.rotate_and_admit!(
                  admission_purpose: "local_sign_in", previous_raw_sid: raw_sid,
                  local_sign_in_flow_ref: first.transaction.public_id,
                )
                locked.redeem!(auth_session: original, admitted_auth_session: admitted)
                [:redeemed, admitted.id]
              end
            rescue BaseAuthAdmissionCoordinator::Denied, AuthCeremonySession::InvalidTransition
              [:refused, nil]
            end
          ensure
            # Leases taken on this pooled thread outlive the future unless released here.
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      backends = Timeout.timeout(10) { Array.new(2) { ready.pop } }
      2.times { release << true }
      results = Timeout.timeout(10) { workers.map(&:value!) }
      winner = results.find { |status, _identity| status == :redeemed }

      assert_equal 2, backends.uniq.length
      assert_equal %i(redeemed refused), results.map(&:first).sort
      assert_equal winner.last, bindings.first.reload.admitted_auth_ceremony_session_id
      assert_not_predicate original.reload, :active?
      assert_equal 1, auth_model.where(previous_sid_digest: original.sid_digest).count
      assert_nil bindings.last.reload.redeemed_at
      assert_predicate sibling.transaction.reload, :sign_in_primary_pending?
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseAuthAdmissionCoordinator.consume_entry_reference!(
          reference: sibling.reference, surface:, expected_intent: "sign_in", binding: bindings.last,
          raw_auth_sid: raw_sid,
        )
      end
    ensure
      2.times { release << true } if release
      workers&.each { |worker| worker.wait(10) }
      bindings&.each(&:delete)
      auth_model&.where(previous_sid_digest: original.sid_digest)&.delete_all if original
      original&.delete
      first&.transaction&.delete
      sibling&.transaction&.delete
    end

    test "#{surface} competing Auth attachment has one winner under real Ticket row locks" do
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = BaseAuthAdmissionCoordinator.admission_binding_model(surface)
      binding = model.find_by!(entry_ref: issuance.reference)
      auth_model = model.auth_admission_session_class
      sessions = Array.new(2) { auth_model.issue!.first }
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      workers =
        sessions.map do |session_record|
          Concurrent::Future.execute do
            model.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              candidate = model.find(binding.id)
              BaseAuthAdmissionCoordinator.with_admission_binding_lock!(candidate) do |locked|
                locked.attach_auth_session!(
                  auth_session: auth_model.find(session_record.id), confirmation_ref: SecureRandom.uuid,
                )
              end
              [:attached, session_record.id]
            rescue AuthAdmissionBinding::InvalidTransition => e
              [:refused, e.class]
            end
          ensure
            # Leases taken on this pooled thread outlive the future unless released here.
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      backends = Timeout.timeout(10) { Array.new(2) { ready.pop } }
      2.times { release << true }
      results = Timeout.timeout(10) { workers.map(&:value!) }
      winner = results.find { |status, _identity| status == :attached }

      assert_equal 2, backends.uniq.length
      assert_equal %i(attached refused), results.map(&:first).sort
      assert_equal winner.last, binding.reload.auth_ceremony_session_id
      assert_nil binding.base_confirmed_at
      assert_nil binding.redeemed_at
      assert sessions.all? { |record| record.reload.active? && !record.admitted? }
    ensure
      2.times { release << true } if release
      workers&.each { |worker| worker.wait(10) }
      binding&.delete
      issuance&.transaction&.delete
      sessions&.each(&:delete)
    end
  end
end
