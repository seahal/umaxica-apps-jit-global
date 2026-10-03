# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpExpiryJobTest < ActiveJob::TestCase
  setup do
    ClientSignUpFlowStatus.ensure_defaults!
    ClientSignUpFlowCleanupStatus.ensure_defaults!
    VisitorSignUpFlowStatus.ensure_defaults!
    VisitorSignUpFlowCleanupStatus.ensure_defaults!
  end

  test "expires overdue in-progress tickets on both ticket databases" do
    now = Time.current.change(usec: 0)
    expired_client = create_flow(ClientSignUpFlow, now: now, expires_at: now - 1.second)
    active_client = create_flow(ClientSignUpFlow, now: now, expires_at: now + 1.second)
    expired_visitor = create_flow(VisitorSignUpFlow, now: now, expires_at: now - 1.second)

    travel_to now do
      SignUpExpiryJob.perform_now(batch_size: 1)
    end

    assert_equal ClientSignUpFlowStatus::EXPIRED, expired_client.reload.status_id
    assert_predicate expired_client.reload, :cleanup_completed?
    assert_equal VisitorSignUpFlowStatus::EXPIRED, expired_visitor.reload.status_id
    assert_predicate active_client.reload, :sign_up_in_progress?
  end

  test "keeps terminal and not-yet-expired tickets unchanged" do
    now = Time.current.change(usec: 0)
    active = create_flow(ClientSignUpFlow, now: now, expires_at: now + 1.minute)
    completed = create_flow(
      ClientSignUpFlow,
      now: now,
      status_id: ClientSignUpFlowStatus::COMPLETED,
      step: "completed",
      expires_at: now - 1.second,
      completed_at: now - 2.seconds,
    )

    travel_to now do
      SignUpExpiryJob.perform_now
    end

    assert_equal ClientSignUpFlowStatus::STARTED, active.reload.status_id
    assert_equal ClientSignUpFlowStatus::COMPLETED, completed.reload.status_id
  end

  test "logs a failed expiry and still expires the other overdue tickets" do
    now = Time.current.change(usec: 0)
    failing = create_flow(ClientSignUpFlow, now: now, expires_at: now - 1.second)
    other = create_flow(VisitorSignUpFlow, now: now, expires_at: now - 1.second)
    real_call = SignUpTermination.method(:call)
    logged = []

    SignUpTermination.stub(
      :call, ->(cycle:, **kwargs) {
               if cycle.id == failing.id && cycle.is_a?(ClientSignUpFlow)
                 raise ActiveRecord::StatementInvalid, "ticket database unavailable"
               end

               real_call.call(cycle: cycle, **kwargs)
             },
    ) do
      Rails.logger.stub(:error, ->(message) { logged << message }) do
        travel_to now do
          SignUpExpiryJob.perform_now
        end
      end
    end

    assert_predicate failing.reload, :sign_up_in_progress?
    assert_equal VisitorSignUpFlowStatus::EXPIRED, other.reload.status_id
    assert logged.any? { |line| line.include?("sign_up.expiry.failed") && line.include?(failing.public_id) }
  end

  test "lets a deadlock escape the per-ticket rescue so the job is retried" do
    now = Time.current.change(usec: 0)
    create_flow(ClientSignUpFlow, now: now, expires_at: now - 1.second)

    SignUpTermination.stub(:call, ->(**) { raise ActiveRecord::Deadlocked, "deadlock detected" }) do
      travel_to now do
        assert_enqueued_with(job: SignUpExpiryJob) { SignUpExpiryJob.perform_now }
      end
    end
  end

  test "logs a ticket the termination left unexpired" do
    now = Time.current.change(usec: 0)
    ticket = create_flow(ClientSignUpFlow, now: now, expires_at: now - 1.second)
    skipped = Struct.new(:status, :ticket).new(:unchanged, nil)
    logged = []

    SignUpTermination.stub(:call, skipped) do
      Rails.logger.stub(:warn, ->(message) { logged << message }) do
        travel_to now do
          SignUpExpiryJob.perform_now
        end
      end
    end

    assert logged.any? { |line| line.include?("sign_up.expiry.skipped") && line.include?(ticket.public_id) }
  end

  test "uses the retention queue" do
    assert_equal "retention", SignUpExpiryJob.queue_name
  end

  private

  def create_flow(model, now:, expires_at:, status_id: nil, step: "start", completed_at: nil)
    model.create!(
      principal_id: nil,
      status_id: status_id || model::STATUS_MODEL::STARTED,
      step: step,
      nonce_digest: model.digest_nonce(SecureRandom.hex(16)),
      issued_at: now - 1.minute,
      expires_at: expires_at,
      completed_at: completed_at,
      entry_method: "email",
    )
  end
end
