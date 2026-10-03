# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthCeremonySessionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  CASES = [
    ClientAuthCeremonySession,
    VisitorAuthCeremonySession,
    OperatorAuthCeremonySession,
  ].freeze

  setup do
    @created_records = []
  end

  teardown do
    @created_records.reverse_each do |model, id|
      model.where(id: id).delete_all
    end
  end

  CASES.each do |model|
    test "#{model.name} serializes concurrent replacement attempts from one predecessor" do
      previous, previous_sid = model.issue!
      @created_records << [model, previous.id]
      previous_ref = "concurrent-previous-#{model.name}-#{SecureRandom.uuid}"
      previous.admit!(admission_purpose: "authentication_handoff", authorization_transaction_ref: previous_ref)

      ready = Queue.new
      release = Queue.new
      results = Queue.new

      # The test database pool is intentionally sized for the two worker
      # connections used by this race. Release the test thread's lease before
      # the workers rendezvous so both operations can hold independent
      # PostgreSQL connections at the same time.
      model.connection_pool.release_connection

      threads =
        2.times.map do |index|
          Thread.new do # rubocop:disable ThreadSafety/NewThread
            model.connection_pool.with_connection do
              ready << true
              release.pop

              replacement, = model.rotate_and_admit!(
                admission_purpose: "authentication_handoff",
                previous_raw_sid: previous_sid,
                authorization_transaction_ref: "concurrent-replacement-#{index}-#{model.name}-#{SecureRandom.uuid}",
              )
              results << [:success, replacement.id]
            rescue StandardError => e
              results << [:error, e.class, e.message]
            end
          end
        end

      2.times { ready.pop }
      2.times { release << true }
      threads.each(&:join)
      outcomes = 2.times.map { results.pop }

      assert_equal 1, outcomes.count { |outcome| outcome.first == :success }, outcomes.inspect
      assert_equal 1, outcomes.count { |outcome| outcome.first == :error }, outcomes.inspect
      error = outcomes.find { |outcome| outcome.first == :error }

      assert_equal AuthCeremonySession::InvalidTransition, error.fetch(1)

      successful_id = outcomes.find { |outcome| outcome.first == :success }.fetch(1)
      @created_records << [model, successful_id]

      assert_equal 1, model.where(previous_sid_digest: previous.sid_digest).count
      assert_equal 1, model.where(
        previous_sid_digest: previous.sid_digest,
        revoked_at: nil,
        completed_at: nil,
        cancelled_at: nil,
      ).count
    end
  end
end
