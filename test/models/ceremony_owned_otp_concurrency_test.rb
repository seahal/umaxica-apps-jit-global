# frozen_string_literal: true

require "test_helper"

class CeremonyOwnedOtpConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  [ClientEmailCeremonyTransaction, VisitorEmailCeremonyTransaction, OperatorEmailCeremonyTransaction].each do |model|
    test "#{model.name} concurrent verification succeeds exactly once" do
      transaction = model.create_transaction!(
        actor_ref: "concurrent-actor", session_ref: "concurrent-browser",
        operation: "registration", email_candidate_ref: "concurrent-candidate",
      )
      code = transaction.issue_email_otp!(purpose: "sign_up")
      ready = Queue.new
      release = Queue.new
      results = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        2.times.map do
          Thread.new do # rubocop:disable ThreadSafety/NewThread
            model.connection_pool.with_connection do
              local = model.find(transaction.id)
              ready << true
              release.pop
              results << local.verify_email_otp!(
                code: code, purpose: "sign_up", actor_ref: "concurrent-actor",
                session_ref: "concurrent-browser", operation: "registration", candidate_ref: "concurrent-candidate",
              )
            end
          rescue StandardError => e
            # A thread that fails before signalling must still answer both queues, or the main
            # thread waits forever and the whole parallel run hangs.
            ready << e
            results << e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      2.times { ready.pop }
      2.times { release << true }
      threads.each(&:value)
      outcomes = 2.times.map { results.pop }

      assert_equal 1, outcomes.count(true)
      assert_equal 1, outcomes.count(false)
      assert transaction.reload.otp_consumed_at
      assert_nil transaction.otp_verifier
    ensure
      transaction&.destroy!
    end
  end

  [ClientTelephoneCeremonyTransaction, VisitorTelephoneCeremonyTransaction,
   OperatorTelephoneCeremonyTransaction,].each do |model|
    test "#{model.name} concurrent verification succeeds exactly once" do
      transaction = model.create_transaction!(
        actor_ref: "concurrent-actor", session_ref: "concurrent-browser",
        operation: "registration", telephone_candidate_ref: "concurrent-candidate",
      )
      code = transaction.issue_telephone_otp!(purpose: "sign_up")
      ready = Queue.new
      release = Queue.new
      results = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        2.times.map do
          Thread.new do # rubocop:disable ThreadSafety/NewThread
            model.connection_pool.with_connection do
              local = model.find(transaction.id)
              ready << true
              release.pop
              results << local.verify_telephone_otp!(
                code: code, purpose: "sign_up", actor_ref: "concurrent-actor",
                session_ref: "concurrent-browser", operation: "registration", candidate_ref: "concurrent-candidate",
              )
            end
          rescue StandardError => e
            # A thread that fails before signalling must still answer both queues, or the main
            # thread waits forever and the whole parallel run hangs.
            ready << e
            results << e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      2.times { ready.pop }
      2.times { release << true }
      threads.each(&:value)
      outcomes = 2.times.map { results.pop }

      assert_equal 1, outcomes.count(true)
      assert_equal 1, outcomes.count(false)
      assert transaction.reload.otp_consumed_at
      assert_nil transaction.otp_verifier
    ensure
      transaction&.destroy!
    end
  end
end
