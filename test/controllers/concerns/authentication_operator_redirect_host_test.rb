# typed: false
# frozen_string_literal: true

require "test_helper"

# An unauthenticated staff request is sent to the staff sign-in host. Which host
# that is depends on the host the request arrived on: a request already on the
# configured staff host stays there, and anything else is sent to the configured
# host rather than being bounced back to whatever host asked. Sending a staff
# sign-in to an arbitrary request host is an open redirect on the staff surface.
class AuthenticationOperatorRedirectHostTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # The concern declares callbacks when included, so the harness has to be a
  # controller. ApplicationController would drag in the surface stack this is
  # deliberately outside of.
  class Harness < ActionController::Base # rubocop:disable Rails/ApplicationController
    include ::AuthenticationOperator

    def invoke(name, ...) = send(name, ...)
  end

  def build_harness(host:)
    request = ActionDispatch::TestRequest.create
    request.host = host
    harness = Harness.new
    harness.set_request!(request)
    harness.set_response!(Harness.make_response!(request))
    harness
  end

  test "a failed staff login is audited against the operator that was attempted" do
    harness = build_harness(host: "attacker.example.com")
    recorded = []
    harness.define_singleton_method(:record_audit) { |event, **kwargs| recorded << [event, kwargs] }
    operator = Struct.new(:id).new(7)

    harness.audit_operator_login_failed(nil)

    assert_empty recorded, "there is nothing to audit when no operator was resolved"

    harness.audit_operator_login_failed(operator)

    assert_equal 1, recorded.size
    assert_equal AuthenticationOperator::AUDIT_EVENTS[:login_failed], recorded.first.first
    assert_equal operator, recorded.first.last.fetch(:resource)
    assert_nil recorded.first.last.fetch(:actor)
  end
end
