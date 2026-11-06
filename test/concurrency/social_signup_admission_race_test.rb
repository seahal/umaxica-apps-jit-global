# frozen_string_literal: true

require "test_helper"
require "timeout"

class SocialSignupAdmissionRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "one OAuth state is consumed by at most one concurrent callback" do
    state = SecureRandom.hex(32)
    SocialAuthCallbackStateStore.issue!(state:, provider: "google", intent: "signup")
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    workers =
      2.times.map do
        Thread.new do
          ClientOauthCallbackState.connection_pool.with_connection do
            ready << true
            start.pop
            results << SocialAuthCallbackStateStore.consume!(state:, provider: "google")
          end
        rescue StandardError => e
          results << e
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end

    2.times { Timeout.timeout(10) { ready.pop } }
    2.times { start << true }
    outcomes = 2.times.map { Timeout.timeout(10) { results.pop } }
    workers.each { |worker| worker.join(10) }
    outcomes.each { |outcome| raise outcome if outcome.is_a?(Exception) }

    assert_equal 1, outcomes.count(true)
    assert_equal 1, outcomes.count(false)
    assert_predicate callback_state_row(state).reload.consumed_at, :present?
  ensure
    workers&.each { |worker| worker.join(10) }
    callback_state_row(state)&.delete if state
  end

  test "concurrent social Flow creation on one admission admits one winner" do
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    workers =
      2.times.map do
        Thread.new do
          OpBaseAppRecord.connection_pool.with_connection do
            ready << true
            start.pop
            locator = SignUpCycleLocator.new({}, surface: :app, cycle_class: ClientSignUpFlow)
            flow = locator.create_for_admission!(
              admission_binding: ClientAuthAdmissionBinding.find(binding.id),
              ceremony_session: ClientAuthCeremonySession.find(ceremony.id),
              entry_method: "google",
              social_provider: "google",
              return_to: "/sign/up?ri=jp",
              reject_prior_flow: true,
            )
            results << [:created, flow.id]
          rescue SignUpCycleLocator::OwnershipMismatch
            results << [:refused]
          end
        rescue StandardError => e
          results << e
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end

    2.times { Timeout.timeout(10) { ready.pop } }
    2.times { start << true }
    outcomes = 2.times.map { Timeout.timeout(10) { results.pop } }
    workers.each { |worker| worker.join(10) }
    outcomes.each { |outcome| raise outcome if outcome.is_a?(Exception) }

    assert_equal [:created, :refused], outcomes.map(&:first).sort
    assert_equal 1, ClientSignUpFlow.where(auth_admission_binding_id: binding.id).count
  ensure
    workers&.each { |worker| worker.join(10) }
    delete_admission!(binding) if binding
  end

  test "a cancellation holding Binding then Ceremony prevents a waiting callback Flow" do
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
    ready = Queue.new
    outcome = Queue.new
    worker = nil

    binding.with_lock do
      ceremony.with_lock do
        worker =
          Thread.new do
            OpBaseAppRecord.connection_pool.with_connection do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()").to_i
              locator = SignUpCycleLocator.new({}, surface: :app, cycle_class: ClientSignUpFlow)
              locator.create_for_admission!(
                admission_binding: ClientAuthAdmissionBinding.find(binding.id),
                ceremony_session: ClientAuthCeremonySession.find(ceremony.id),
                entry_method: "google",
                social_provider: "google",
                return_to: "/sign/up?ri=jp",
                reject_prior_flow: true,
              ) do |flow|
                ClientAuthCeremonySession.find(ceremony.id).with_lock do
                  unless ClientAuthCeremonySession.find(ceremony.id).active?
                    raise SignUpCycleLocator::OwnershipMismatch, "ceremony was canceled"
                  end

                  SignUpStateMachine.call(
                    ticket: flow, event: :start_social_callback,
                    actor_context: Actor.authn,
                  )
                end
              end
              outcome << :created
            end
          rescue SignUpCycleLocator::OwnershipMismatch
            outcome << :refused
          rescue StandardError => e
            outcome << e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end

        pid = Timeout.timeout(10) { ready.pop }
        Timeout.timeout(10) do
          loop do
            blocked =
              OpBaseAppRecord.uncached do
                OpBaseAppRecord.connection.select_value(
                  "SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0",
                )
              end
            break if blocked

            Thread.pass
          end
        end
        ceremony.cancel!
      end
    end

    result = Timeout.timeout(10) { outcome.pop }
    raise result if result.is_a?(Exception)

    worker.join(10)

    assert_equal :refused, result
    assert_equal AuthCeremonySession::STATUS_CANCELLED_BEFORE_PROGRESS, ceremony.reload.status_id
    assert_equal 0, ClientSignUpFlow.where(auth_admission_binding_id: binding.id).count
  ensure
    worker&.join(10)
    delete_admission!(binding) if binding
  end

  private

  def callback_state_row(state)
    ClientOauthCallbackState.find_by(state_digest: ClientOauthCallbackState.digest_state(state))
  end

  def delete_admission!(binding)
    binding.reload
    session_ids = [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id].compact.uniq
    parent_id = binding.authorization_transaction_id
    ClientSignUpFlow.where(auth_admission_binding_id: binding.id).delete_all
    ClientAuthAdmissionBinding.where(id: binding.id).delete_all
    ClientAuthCeremonySession.where(id: session_ids).delete_all if session_ids.any?
    ClientOidcAuthorizationTransaction.where(id: parent_id).delete_all if parent_id
  end
end
