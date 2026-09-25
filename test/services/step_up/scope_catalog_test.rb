# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StepUpScopeCatalogTest < ActiveSupport::TestCase
  test "settings mfa uses the mfa challenge path on every surface" do
    path = "/settings/mfa/challenge"

    assert_match StepUpScopeCatalog::APP.fetch("settings_mfa"), path
    assert_match StepUpScopeCatalog::COM.fetch("settings_mfa"), path
    assert_match StepUpScopeCatalog::ORG.fetch("settings_mfa"), path
  end

  test "later step up scopes remain registered" do
    assert StepUpScopeCatalog::APP.key?("social_link")
    assert StepUpScopeCatalog::ORG.key?("operator_lifecycle")
    assert_match StepUpScopeCatalog::ORG.fetch("operator_lifecycle"), "/identity/withdrawal?ri=jp"
    assert_match StepUpScopeCatalog::ORG.fetch("operator_lifecycle"), "/settings/operator_lifecycle_requests"
  end

  test "social link scope is offered on app and org and matches social settings pages" do
    app_pattern = StepUpScopeCatalog::APP.fetch("social_link")

    assert_match app_pattern, "/settings/google"
    assert_match app_pattern, "/settings/google/edit?ri=jp"
    assert_match app_pattern, "/settings/apple?ri=jp"
    assert_match app_pattern, "/settings/apple/edit"
    assert_no_match app_pattern, "/social/auth/google_app/continue"
    assert_no_match app_pattern, "/settings/emails"

    # Org links Google only (no Apple); com offers no social linking.
    org_pattern = StepUpScopeCatalog::ORG.fetch("social_link")

    assert_match org_pattern, "/settings/google"
    assert_match org_pattern, "/settings/google?ri=jp"
    assert_no_match org_pattern, "/settings/apple"
    assert_no_match org_pattern, "/social/auth/google_#{"org"}/continue"
    assert_not StepUpScopeCatalog::COM.key?("social_link")
  end

  test "social unlink scope matches only provider settings pages" do
    app_pattern = StepUpScopeCatalog::APP.fetch("social_unlink")

    assert_match app_pattern, "/settings/google"
    assert_match app_pattern, "/settings/google/edit?ri=jp"
    assert_match app_pattern, "/settings/apple"
    assert_match app_pattern, "/settings/apple/edit"
    assert_no_match app_pattern, "/social/google/disconnection"
    assert_no_match app_pattern, "/settings/emails"
  end

  test "settings birthdate scope only matches the birthdate path" do
    app_pattern = StepUpScopeCatalog::APP.fetch("settings_birthdate")
    com_pattern = StepUpScopeCatalog::COM.fetch("settings_birthdate")
    org_pattern = StepUpScopeCatalog::ORG.fetch("settings_birthdate")

    [app_pattern, com_pattern, org_pattern].each do |pattern|
      assert_match pattern, "/settings/birthdate"
      assert_match pattern, "/settings/birthdate?ri=jp"
      assert_no_match pattern, "/settings/birthdate_extra"
      assert_no_match pattern, "/settings/birthdate/extra"
    end
  end

  test "generic identity secret scope remains only on com and org" do
    app_pattern = StepUpScopeCatalog::APP.fetch("settings_secret_credential")
    com_pattern = StepUpScopeCatalog::COM.fetch("settings_secret_credential")
    org_pattern = StepUpScopeCatalog::ORG.fetch("settings_secret_credential")

    assert_no_match app_pattern, "/identity/secrets"
    assert_match com_pattern, "/identity/secrets"
    assert_match org_pattern, "/identity/secrets"
  end

  test "org session revoke scope includes support session actions" do
    pattern = StepUpScopeCatalog::ORG.fetch("session_revoke_all")

    assert_match pattern, "/support/clients/123/sessions/purge"
    assert_match pattern, "/support/visitors/123/sessions/emergency_revoke"
    assert_match pattern, "/support/operators/123/sessions/purge"
    assert_no_match pattern, "/support/clients/abc/sessions/purge"
    assert_no_match StepUpScopeCatalog::APP.fetch("session_revoke_all"), "/support/clients/123/sessions/purge"
  end

  test "Avatar transfer Step-Up scopes are operation-specific and absent from com" do
    request_path = "/avatar_ownership_transfers?ri=jp"
    accept_path = "/avatar_ownership_transfers/transfer-123/accept?ri=jp"
    cancel_path = "/avatar_ownership_transfers/transfer-123/cancel?ri=jp"

    %w(avatar_transfer_request avatar_transfer_accept avatar_transfer_cancel).each do |scope|
      assert StepUpScopeCatalog::APP.key?(scope)
      assert StepUpScopeCatalog::ORG.key?(scope)
      assert_not StepUpScopeCatalog::COM.key?(scope)
    end
    assert_match StepUpScopeCatalog::APP.fetch("avatar_transfer_request"), request_path
    assert_match StepUpScopeCatalog::ORG.fetch("avatar_transfer_accept"), accept_path
    assert_match StepUpScopeCatalog::APP.fetch("avatar_transfer_cancel"), cancel_path
    assert_no_match StepUpScopeCatalog::APP.fetch("avatar_transfer_accept"), cancel_path
    assert_no_match StepUpScopeCatalog::ORG.fetch("avatar_transfer_cancel"), accept_path
    assert_no_match StepUpScopeCatalog::ORG.fetch("avatar_transfer_accept"), "/avatar_ownership_transfers/transfer-123/accept-extra"
  end
end
