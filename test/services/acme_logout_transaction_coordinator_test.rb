# typed: false
# frozen_string_literal: true

require "test_helper"

# A logout transaction may only be finalized once every clearing step it is
# waiting on has been recorded. Finalizing early is a protocol error the caller
# has to be told about as a rejected result, not an exception that escapes into
# the logout response.
class AcmeLogoutTransactionCoordinatorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def issue_transaction
    AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "sign",
      initiating_client_id: "core-app",
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: "sign", ri: "jp", surface: "app",
      ),
      surface: "app",
      ri: "jp",
    ).transaction
  end

  test "finalizing before the clearing steps are recorded is rejected rather than raised" do
    transaction = issue_transaction

    result = AcmeLogoutTransactionCoordinator.finalize!(logout_challenge: transaction.logout_challenge)

    assert_equal :rejected, result.status
    assert_equal "invalid_request", result.error
    assert_match(/not ready to finalize/, result.error_description)
    assert_not_predicate transaction.reload, :finalized?
  end

  test "finalizing an unknown challenge reports the transaction as missing" do
    result = AcmeLogoutTransactionCoordinator.finalize!(logout_challenge: "no-such-challenge")

    assert_equal :missing, result.status
    assert_equal "not_found", result.error
  end

  test "finalizing after every clearing step has been recorded completes the transaction" do
    transaction = issue_transaction
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "acme_cleared")

    result = AcmeLogoutTransactionCoordinator.finalize!(logout_challenge: transaction.logout_challenge)

    assert_equal :finalized, result.status
    assert_predicate transaction.reload, :finalized?
  end
end
