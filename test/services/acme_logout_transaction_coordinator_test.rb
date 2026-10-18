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
      initiating_client_id: "core-app-jp",
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

  test "Warp route issuance retains the established logout transaction enum" do
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(
      origin_surface: "warp", ri: "jp", surface: "app",
    )
    uri = URI.parse(completion_url)

    assert_equal Rails.configuration.x.boot_config.fetch(:hosts).warp_service.host, uri.host
    assert_equal "/sign/out/completion", uri.path

    result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "warp",
      initiating_client_id: "warp-app-jp",
      completion_url: completion_url,
      surface: "app",
      ri: "jp",
    )

    assert_predicate result, :success?
    assert_equal "warp", result.transaction.origin_surface
    assert_equal AcmeLogoutTransaction.step_sequence_for("warp").first, result.transaction.expected_step
  end

  test "Browser RP issuance uses the registered client realm and authority-first graph" do
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(
      origin_surface: "warp", ri: "jp", surface: "app",
    )
    result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "warp",
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      initiating_client_id: "warp-app-jp",
      completion_url: completion_url,
      actor_ref: "actor",
      session_ref: "rp-session",
      binding_version: 1,
      realm: "app",
      parent_session_ref: "device-session",
      captured_root_ref: "root-token",
      root_refresh_family_ref: "refresh-family",
      captured_root_generation: 0,
      origin_intent_digest: "d".b * 32,
      surface: "app",
      ri: "jp",
    )

    assert_predicate result, :success?
    assert_equal AcmeLogoutTransaction::BROWSER_RP_WORKFLOW, result.transaction.workflow
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, result.transaction.expected_step
    assert_equal [], result.transaction.completed_steps
  end

  test "Browser RP issuance rejects a missing authority binding" do
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(
      origin_surface: "warp", ri: "jp", surface: "app",
    )

    result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "warp",
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      initiating_client_id: "warp-app-jp",
      completion_url: completion_url,
      session_ref: "rp-session",
    )

    assert_equal :rejected, result.status
    assert_equal "invalid_request", result.error
    assert_match(/authority binding/, result.error_description)
  end

  test "Browser RP issuance rejects Auth and supports Palm and Tech origins" do
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(
      origin_surface: "core", ri: "jp", surface: "app",
    )

    auth_result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "sign",
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      initiating_client_id: "core-app-jp",
      completion_url: completion_url,
    )
    palm_result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "palm",
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      initiating_client_id: "palm-app-jp",
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: "palm", ri: "jp", surface: "app",
      ),
      actor_ref: "palm-actor",
      session_ref: "palm-session",
      **browser_binding_attributes(realm: "app"),
    )
    tech_result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "tech",
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      initiating_client_id: "tech-org-ww",
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: "tech", ri: "jp", surface: "org",
      ),
      actor_ref: "tech-actor",
      session_ref: "tech-session",
      surface: "org",
      **browser_binding_attributes(realm: "org"),
    )

    assert_equal :rejected, auth_result.status
    assert_predicate palm_result, :success?
    assert_equal "/sign/out/completion", URI.parse(palm_result.transaction.completion_url).path
    assert_predicate tech_result, :success?
    assert_equal "tech", tech_result.transaction.origin_surface
    assert_equal "/sign/out/completion", URI.parse(tech_result.transaction.completion_url).path
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

  private

  def browser_binding_attributes(realm:)
    {
      binding_version: AcmeLogoutTransaction::BINDING_VERSION_BROWSER_RP,
      realm: realm,
      parent_session_ref: "device-session",
      captured_root_ref: "root-token",
      root_refresh_family_ref: "refresh-family",
      captured_root_generation: 0,
      origin_intent_digest: "d".b * 32,
    }
  end
end
