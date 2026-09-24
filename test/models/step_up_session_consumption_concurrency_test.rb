# typed: false
# frozen_string_literal: true

require "test_helper"

# This uses committed rows and independent PostgreSQL connections. A transaction-local or mocked
# concurrency test cannot prove that only one worker consumes the same step-up session.
# rubocop:disable ThreadSafety/NewThread
class StepUpSessionConsumptionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
    @token = ClientToken.create!(user: @user)
    @step_up_session = ClientStepUpSession.create!(
      user_token: @token,
      scope: "account_update",
      return_to: "/account",
      status: "PENDING",
      discard_at: 10.minutes.from_now,
    )
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  teardown do
    ClientStepUpSession.where(id: @step_up_session&.id).delete_all
    ClientToken.where(id: @token&.id).delete_all
    ClientAuthorityLock.where(client_id: @user&.id).delete_all
    Client.where(id: @user&.id).delete_all
  end

  test "concurrent consumers produce exactly one result and destroy the session once" do
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    now = Time.current

    threads =
      2.times.map do
        Thread.new do # rubocop:disable ThreadSafety/NewThread
          AppTicketRecord.connection_pool.with_connection do
            ready << true
            release.pop
            result =
              ClientStepUpSession.consume_pending!(id: @step_up_session.id, now: now) do |locked|
                locked.id
              end
            results << result
          rescue StandardError => e
            results << e
          end
        end
      end

    2.times { ready.pop }
    2.times { release << true }
    threads.each(&:join)

    outcomes = 2.times.map { results.pop }

    assert_empty outcomes.grep(Exception), outcomes.grep(Exception).map(&:message).join("\n")
    assert_equal [@step_up_session.id], outcomes.compact
    assert_nil ClientStepUpSession.find_by(id: @step_up_session.id)
  end
end
# rubocop:enable ThreadSafety/NewThread
