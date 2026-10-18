# typed: false
# frozen_string_literal: true

require "test_helper"

# Terminating a sign-up is idempotent: the same terminal event arriving twice has
# to finish the cleanup rather than report a failed transition, because the
# second arrival is usually a retry of a request whose response was lost. An
# event that is not terminal at all is a different thing entirely and is refused.
class SignUpTerminationIdempotenceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup { ClientSignUpFlowStatus.ensure_defaults! }

  def ticket(status_name)
    ClientSignUpFlow.new(
      step: "contact",
      entry_method: "email",
      status_id: ClientSignUpFlow::STATUS_NAMES.key(status_name),
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
    )
  end

  test "an event that is not a terminal one is refused as an invalid transition" do
    result = SignUpTermination.call(cycle: ticket("STARTED"), event: :advance)

    assert_equal :invalid_transition, result.status
    assert_includes result.errors, "unknown terminal event"
  end

  test "a termination with no ticket is blocked rather than attempted" do
    result = SignUpTermination.call(cycle: nil, event: :cancel)

    assert_equal :blocked, result.status
    assert_includes result.errors, "ticket is required"
  end

  test "replaying a terminal event without cleanup support is a no-op success" do
    expired = Object.new
    expired.define_singleton_method(:status_id) { ClientSignUpFlow::STATUS_NAMES.key("EXPIRED") }
    klass =
      Class.new do
        const_set(:STATUS_NAMES, ClientSignUpFlow::STATUS_NAMES)
      end
    expired.define_singleton_method(:class) { klass }
    expired.define_singleton_method(:reload) { expired }
    expired.define_singleton_method(:step) { "contact" }
    expired.define_singleton_method(:respond_to?) { |name, *| %i(cleanup_pending? discard_now!).exclude?(name) }

    result = SignUpTermination.call(cycle: expired, event: :expire)

    assert_equal :ok, result.status
    assert_equal expired, result.ticket
  end
end
