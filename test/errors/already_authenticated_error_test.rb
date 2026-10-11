# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AlreadyAuthenticatedErrorTest < ActiveSupport::TestCase
  test "uses the fixed minimal rejection message" do
    error = AlreadyAuthenticatedError.new

    assert_nil error.i18n_key
    assert_equal "Sign-in is unavailable while authenticated.", error.message
  end

  test "initializes with conflict status code" do
    error = AlreadyAuthenticatedError.new

    assert_equal :conflict, error.status_code
  end

  test "accepts custom status code" do
    error = AlreadyAuthenticatedError.new(nil, :unauthorized)

    assert_equal :unauthorized, error.status_code
  end

  test "accepts context keyword arguments" do
    error = AlreadyAuthenticatedError.new(session_id: "abc123")

    assert_equal "abc123", error.context[:session_id]
  end

  test "inherits from ApplicationError" do
    assert_kind_of ApplicationError, AlreadyAuthenticatedError.new
  end

  test "can be raised and caught" do
    assert_raises(AlreadyAuthenticatedError) do
      raise AlreadyAuthenticatedError.new
    end
  end
end
