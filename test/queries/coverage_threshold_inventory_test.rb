# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdCredentialInventoryTest < ActiveSupport::TestCase
  test "credential inventory result predicates describe populated credential sets" do
    result = AuthenticationCredentialInventory::Result.new(
      actor: nil, excluding: nil, sign_in_methods: [:email],
      step_up_methods: [:totp], uv_step_up_methods: [:passkey],
      contact_identifiers: [:email], phishing_resistant_methods: [:passkey],
    )

    assert_equal [:email], result.sign_in_methods
    assert_equal [:email], result.usable_sign_in_capabilities
    assert_equal [:passkey], result.usable_step_up_capabilities
    assert_equal 1, result.usable_sign_in_capabilities.length
    assert_equal 1, result.contact_identifier_count
    assert_predicate result, :has_usable_sign_in_capability?
    assert_predicate result, :has_usable_step_up_capability?
    assert_equal 1, result.contact_identifier_count
    assert_equal 1, result.usable_step_up_capabilities.length
  end

  test "empty credential inventory identifies last methods" do
    result = AuthenticationCredentialInventory::Result.new(
      actor: nil, excluding: nil, sign_in_methods: [], step_up_methods: [],
      uv_step_up_methods: [], contact_identifiers: [], phishing_resistant_methods: [],
    )

    assert_not_predicate result, :has_usable_sign_in_capability?
    assert_not_predicate result, :has_usable_step_up_capability?
    assert_equal 0, result.contact_identifier_count
  end
end
