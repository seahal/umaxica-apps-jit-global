# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class SignUpFlowAdmissionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  [
    [:app, "client", ClientSignUpFlow, ClientAuthAdmissionBinding, ClientAuthCeremonySession],
    [:com, "visitor", VisitorSignUpFlow, VisitorAuthAdmissionBinding, VisitorAuthCeremonySession],
  ].each do |surface, realm, flow_class, binding_class, ceremony_class|
    test "#{surface} simultaneous Flow inserts on separate connections claim one Admission slot" do
      client_id = "core-#{surface}-jp"
      parent = OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface, intent: "authentication",
        params: {
          client_id: client_id,
          redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
          response_type: "code",
          scope: "openid profile",
          prompt: "create",
          state: SecureRandom.hex(16),
          nonce: SecureRandom.hex(16),
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
        },
      ).transaction
      issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: parent, base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = binding_class.find_by!(entry_ref: issuance.reference)
      attached, raw_sid = ceremony_class.issue!
      binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
      binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
      ceremony, = ceremony_class.rotate_and_admit!(
        admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
        authorization_transaction_ref: parent.transaction_id,
      )
      binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      workers =
        Array.new(2) do
          Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
            flow_class.connection_class_for_self.connected_to(role: :writing) do
              flow_class.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                now = flow_class.database_now
                flow = flow_class.create!(
                  auth_admission_binding: binding_class.find(binding.id), step: "start", entry_method: "email",
                  issued_at: now, expires_at: now + 15.minutes,
                  nonce_digest: flow_class.digest_nonce(SecureRandom.hex(32)),
                )
                [:created, flow.id]
              rescue ActiveRecord::RecordNotUnique
                [:conflict]
              end
            end
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      backends = Timeout.timeout(10) { Array.new(2) { ready.pop } }
      2.times { release << true }
      results = Timeout.timeout(10) { workers.map(&:value!) }

      assert_equal 2, backends.uniq.length
      assert_equal %i(conflict created), results.map(&:first).sort
      assert_equal 1, flow_class.where(auth_admission_binding_id: binding.id).count
      assert_equal results.find { |result| result.first == :created }.last,
                   flow_class.find_by!(auth_admission_binding_id: binding.id).id
      assert_equal ceremony.id, binding.reload.admitted_auth_ceremony_session_id
    ensure
      2.times { release << true } if release
      workers&.each { |worker| worker.wait(10) }
      if binding
        flow_class.where(auth_admission_binding_id: binding.id).delete_all
        binding.delete
      end
      parent&.delete
      ceremony&.delete
      attached&.delete
    end
  end
end
