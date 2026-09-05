# typed: false
# frozen_string_literal: true

require "test_helper"

# Staff telephone verification is the weakest link in the operator sign-up
# chain: it accepts a code for a row named by id. The guards here decide that a
# row which is missing, already verified, or past its code window is refused as
# an expired session rather than verified, and that repeated attempts from one
# address are stopped before they become an oracle.
class SignOperatorTelephoneRegistrableGuardsTest < ActiveSupport::TestCase
  counts_rate_limits!
  self.fixture_table_names = []

  class Harness
    include SignOperatorTelephoneRegistrable

    attr_accessor :remote_ip

    def request = Struct.new(:remote_ip).new(remote_ip || "203.0.113.9")

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "a code submitted for a telephone row that does not exist is refused as an expired session" do
    assert_equal :session_expired, @harness.invoke(:complete_staff_telephone_verification, 0, "123456")
  end

  test "the verified telephone lookup is scoped to the statuses that count as verified" do
    staff = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)

    scope = @harness.invoke(:verified_staff_telephones_for, staff)

    assert_empty scope
    assert_equal OperatorTelephone, scope.klass
  end

  test "repeated verification attempts from one address are refused once the window limit is passed" do
    @harness.remote_ip = "198.51.100.7"

    SignOperatorTelephoneRegistrable::TELEPHONE_VERIFICATION_RATE_LIMIT.times do
      @harness.invoke(:check_staff_telephone_verification_rate_limit!)
    end

    assert_raises(ActionController::TooManyRequests) do
      @harness.invoke(:check_staff_telephone_verification_rate_limit!)
    end
  end
end
