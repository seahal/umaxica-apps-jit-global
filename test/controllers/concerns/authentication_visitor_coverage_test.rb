# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationVisitorCoverageTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthenticationVisitor

    attr_accessor :current_resource, :audit_calls

    def initialize
      super
      @audit_calls = []
    end

    def record_audit(*args, **kwargs)
      @audit_calls << [args, kwargs]
      super
    end
  end

  test "audit_visitor_login_failed records a login-failed event for a present visitor" do
    harness = Harness.new
    visitor = Visitor.new
    recorded = []
    harness.define_singleton_method(:record_audit) { |event, **kwargs| recorded << [event, kwargs] }

    harness.audit_visitor_login_failed(nil)
    harness.audit_visitor_login_failed(visitor)

    assert_equal 1, recorded.size
    assert_equal AuthenticationVisitor::AUDIT_EVENTS[:login_failed], recorded.first.first
    assert_nil recorded.first.last[:actor]
  end
end
