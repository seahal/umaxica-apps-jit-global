# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StepUpScopeCatalogTest < ActiveSupport::TestCase
  [StepUpScopeCatalog::APP, StepUpScopeCatalog::COM, StepUpScopeCatalog::ORG].each_with_index do |catalog, index|
    test "surface #{index} operation path prefixes require a segment boundary" do
      paths = {
        "session_revoke_all" => %w(/sign/settings/sessions /settings/sessions /sessions /identity/sessions),
        "withdrawal" => %w(/settings/withdrawal /identity/withdrawal),
        "settings_email" => %w(/settings/emails /identity/emails),
        "settings_telephone" => %w(/settings/telephones /identity/telephones),
        "settings_passkey" => %w(/settings/passkeys),
      }
      paths.each do |scope, roots|
        roots.each do |root|
          pattern = catalog.fetch(scope)

          assert_match pattern, root
          assert_match pattern, "#{root}?ri=jp"
          assert_match pattern, "#{root}/existing-resource"
          %w(-extra _extra 0 %2Fextra).each do |suffix|
            assert_no_match pattern, "#{root}#{suffix}"
          end
        end
      end
    end
  end

  test "actor-specific registration and lifecycle path prefixes require a segment boundary" do
    {
      StepUpScopeCatalog::APP.fetch("settings_totp") => "/settings/totps",
      StepUpScopeCatalog::COM.fetch("settings_secret_credential") => "/identity/secrets",
      StepUpScopeCatalog::ORG.fetch("operator_lifecycle") => "/settings/operator_lifecycle_requests",
    }.each do |pattern, root|
      assert_match pattern, root
      assert_match pattern, "#{root}/existing-resource"
      assert_match pattern, "#{root}?ri=jp"
      assert_no_match pattern, "#{root}-extra"
      assert_no_match pattern, "#{root}_extra"
    end
    assert_no_match StepUpScopeCatalog::ORG.fetch("settings_secret_credential"), "/settings/secrets-extra"
    assert_no_match StepUpScopeCatalog::COM.fetch("settings_secret_credential"), "/settings/secret_credentials-extra"
  end

  test "settings mfa uses the mfa challenge path on every surface" do
    path = "/identity/mfa/challenge"

    assert_match StepUpScopeCatalog::APP.fetch("settings_mfa"), path
    assert_match StepUpScopeCatalog::COM.fetch("settings_mfa"), path
    assert_match StepUpScopeCatalog::ORG.fetch("settings_mfa"), path
    [StepUpScopeCatalog::APP, StepUpScopeCatalog::COM, StepUpScopeCatalog::ORG].each do |catalog|
      assert_match catalog.fetch("settings_mfa"), "#{path}?ri=jp"
      assert_no_match catalog.fetch("settings_mfa"), "#{path}-extra"
      assert_no_match catalog.fetch("settings_mfa"), "#{path}/extra"
      assert_no_match catalog.fetch("settings_mfa"), "/settings/mfa/challenge"
    end
  end

  test "later step up scopes remain registered" do
    assert StepUpScopeCatalog::APP.key?("social_link")
    assert StepUpScopeCatalog::ORG.key?("operator_lifecycle")
    assert_match StepUpScopeCatalog::ORG.fetch("operator_lifecycle"), "/identity/withdrawal?ri=jp"
    assert_match StepUpScopeCatalog::ORG.fetch("operator_lifecycle"), "/settings/operator_lifecycle_requests"
  end

  test "social link scope is offered only on app and matches its provider settings pages" do
    app_pattern = StepUpScopeCatalog::APP.fetch("social_link")

    assert_match app_pattern, "/settings/google"
    assert_match app_pattern, "/settings/google/edit?ri=jp"
    assert_match app_pattern, "/settings/apple?ri=jp"
    assert_match app_pattern, "/settings/apple/edit"
    assert_no_match app_pattern, "/social/auth/google_app/continue"
    assert_no_match app_pattern, "/settings/emails"

    assert_not StepUpScopeCatalog::ORG.key?("social_link")
    assert_not StepUpScopeCatalog::ORG.key?("social_unlink")
    assert_not StepUpScopeCatalog::COM.key?("social_link")
    assert_not StepUpScopeCatalog::COM.key?("social_unlink")
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

  # Support revocation has its own scope, separate from the operator's own session revocation, and
  # only for the app and com targets. The org enforcement realm has no catalogued scope.
  test "org support revocation and enforcement scopes cover only their confirmation screens" do
    own_sessions = StepUpScopeCatalog::ORG.fetch("session_revoke_all")
    support = StepUpScopeCatalog::ORG.fetch("support_session_revoke")

    assert_no_match own_sessions, "/support/clients/0123456789ABCDEF/revocations/new"
    assert_match support, "/support/clients/0123456789ABCDEF/revocations/new"
    assert_match support, "/support/visitors/0123456789ABCDEF/revocations/new?ri=jp"
    assert_no_match support, "/support/operators/0123456789ABCDEF/revocations/new"
    assert_no_match support, "/support/clients/0123456789ABCDEF/revocations/new/extra"
    assert_match StepUpScopeCatalog::ORG.fetch("enforcement_case_approve"),
                 "/support/com/enforcement_cases/abc/approval/new"
    assert_no_match StepUpScopeCatalog::ORG.fetch("enforcement_case_approve"),
                    "/support/org/enforcement_cases/abc/approval/new"
    assert_match StepUpScopeCatalog::ORG.fetch("operator_capability"), "/iam/grants/new"
    assert_not StepUpScopeCatalog::APP.key?("support_session_revoke")
    assert_not StepUpScopeCatalog::COM.key?("enforcement_case_apply")
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
    assert_no_match StepUpScopeCatalog::ORG.fetch("avatar_transfer_accept"),
                    "/avatar_ownership_transfers/transfer-123/accept-extra"
  end
end
