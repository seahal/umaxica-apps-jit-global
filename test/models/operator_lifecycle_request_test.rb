# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorLifecycleRequestTest < ActiveSupport::TestCase
  test "closed? returns true for rejected, executed or cancelled status" do
    req = OperatorLifecycleRequest.new(status: "rejected")

    assert_predicate req, :closed?

    req = OperatorLifecycleRequest.new(status: "executed")

    assert_predicate req, :closed?

    req = OperatorLifecycleRequest.new(status: "cancelled")

    assert_predicate req, :closed?

    req = OperatorLifecycleRequest.new(status: "pending")

    assert_not req.closed?
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorLifecycleRequest)
  end
end
