# frozen_string_literal: true

require "test_helper"

class ValkeyAuthStateAuthorizationCodeConsumeResultTest < ActiveSupport::TestCase
  Result = Valkey::AuthState::AuthorizationCodeStore::ConsumeResult

  test "expired? is true only for the expired status" do
    assert_predicate Result.new(status: :expired, payload: nil), :expired?
    assert_not Result.new(status: :consumed, payload: nil).expired?
    assert_not Result.new(status: :missing, payload: nil).expired?
  end

  test "payload is retained for a consumed result" do
    result = Result.new(status: :consumed, payload: { "client_id" => "core-app-rp" })

    assert_equal({ "client_id" => "core-app-rp" }, result.payload)
    assert_equal :consumed, result.status
  end
end
