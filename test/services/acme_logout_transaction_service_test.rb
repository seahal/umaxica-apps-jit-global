# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AcmeLogoutTransactionCoordinatorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "issue! persists an allowlisted completion url and public challenge" do
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(origin_surface: "core")
    result =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "core",
        initiating_client_id: "core-app",
        completion_url: completion_url,
        actor_ref: "actor_xxx",
        session_ref: "session_xxx",
      )

    assert_predicate result, :success?
    assert_predicate result.transaction.logout_challenge, :present?
    assert_equal "core", result.transaction.origin_surface
    assert_equal completion_url, result.transaction.completion_url
  end

  test "issue! accepts canonical jp completion url" do
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(origin_surface: "core", ri: "jp")

    result =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "core",
        initiating_client_id: "core-app",
        completion_url: completion_url,
        ri: "jp",
      )

    assert_predicate result, :success?
    assert_equal completion_url, result.transaction.completion_url
    assert_includes result.transaction.completion_url, "ri=jp"
  end

  test "issue! accepts canonical us completion url" do
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(origin_surface: "core", ri: "us")

    result =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "core",
        initiating_client_id: "core-app",
        completion_url: completion_url,
        ri: "us",
      )

    assert_predicate result, :success?
    assert_equal completion_url, result.transaction.completion_url
    assert_includes result.transaction.completion_url, "ri=us"
  end

  test "issue! does not compare us completion url against jp expected url" do
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(origin_surface: "base", ri: "us")

    result =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "base",
        initiating_client_id: "core-app",
        completion_url: completion_url,
        ri: "us",
      )

    assert_predicate result, :success?
    assert_equal completion_url, result.transaction.completion_url
  end

  test "advance! rejects wrong step and tampered challenges safely" do
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(origin_surface: "sign")
    transaction =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "sign",
        initiating_client_id: "core-app",
        completion_url: completion_url,
      ).transaction

    rejected = AcmeLogoutTransactionCoordinator.advance!(
      logout_challenge: transaction.logout_challenge,
      step: "acme_cleared",
    )

    assert_equal :rejected, rejected.status
    assert_equal "invalid_request", rejected.error

    missing = AcmeLogoutTransactionCoordinator.advance!(logout_challenge: "tampered", step: "origin_cleared")

    assert_equal :missing, missing.status
    assert_equal "not_found", missing.error
  end

  test "finalize! is replay safe" do
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(origin_surface: "sign")
    transaction =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "sign",
        initiating_client_id: "core-app",
        completion_url: completion_url,
      ).transaction

    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "acme_cleared")

    result = AcmeLogoutTransactionCoordinator.finalize!(logout_challenge: transaction.logout_challenge)

    assert_equal :finalized, result.status

    replay = AcmeLogoutTransactionCoordinator.finalize!(logout_challenge: transaction.logout_challenge)

    assert_equal :finalized, replay.status
    assert_predicate replay.transaction, :finalized?
  end

  test "completion url is not arbitrary return_to" do
    result =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "sign",
        initiating_client_id: "core-app",
        completion_url: "https://attacker.example/signed-out",
      )

    assert_equal :rejected, result.status
    assert_equal "invalid_request", result.error
  end

  test "issue! rejects unsupported or unregistered completion url" do
    completion_url = AcmeLogoutTransactionCoordinator
      .completion_url_for(origin_surface: "sign", ri: "jp")
      .sub("ri=jp", "ri=xx")

    result =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "sign",
        initiating_client_id: "core-app",
        completion_url: completion_url,
        ri: "xx",
      )

    assert_equal :rejected, result.status
    assert_equal "invalid_request", result.error
  end
end
