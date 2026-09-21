# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationPurposeContractTest < ActiveSupport::TestCase
  test "ordinary sign in and sign up handoffs and results share neutral purposes" do
    assert_equal "authentication_handoff", issued_purpose_for(intent: "sign_in", kind: :handoff)
    assert_equal "authentication_handoff", issued_purpose_for(intent: "sign_up", kind: :handoff)
    assert_equal "authentication_result", issued_purpose_for(intent: "sign_in", kind: :result)
    assert_equal "authentication_result", issued_purpose_for(intent: "sign_up", kind: :result)
  end

  test "special-purpose handoffs and results remain distinct" do
    purposes = %w(invitation step_up reauthentication)

    handoffs = purposes.map { |intent| issued_purpose_for(intent:, kind: :handoff) }
    results = purposes.map { |intent| issued_purpose_for(intent:, kind: :result) }

    assert_equal %w(invitation_handoff step_up_handoff reauthentication_handoff), handoffs
    assert_equal %w(invitation_result step_up_result reauthentication_result), results
    assert_equal handoffs.length, handoffs.uniq.length
    assert_equal results.length, results.uniq.length
  end

  test "opaque store allows only the current purpose vocabulary" do
    assert_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "authentication_handoff"
    assert_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "authentication_result"
    assert_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "invitation_handoff"
    assert_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "reauthentication_result"
    assert_not_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "sign_in_handoff"
    assert_not_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "sign_up_result"
  end

  private

  def issued_purpose_for(intent:, kind:)
    store = PurposeCaptureStore.new
    transaction = Struct.new(:intent, :surface, :transaction_id, :session_ref).new(
      intent,
      "app",
      "transaction-1",
      "session-1",
    )

    if kind == :handoff
      BaseAuthAdmissionCoordinator.issue_handoff!(transaction:, store:)
    else
      BaseAuthAdmissionCoordinator.issue_result!(transaction:, store:)
    end

    store.purpose
  end

  class PurposeCaptureStore
    attr_reader :purpose

    def issue!(purpose:, **)
      @purpose = purpose
      "opaque-code"
    end
  end
end
