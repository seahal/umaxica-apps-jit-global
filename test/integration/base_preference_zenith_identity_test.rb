# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class BasePreferenceZenithIdentityTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  fixtures :clients, :operators

  test "Base APP account preference writes resolve the verified Base cell subject in Zenith" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = clients(:one)
    other_actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    root_token = authentication_harness_create_token(actor)
    host! host
    https!

    as_rp_cell("base-app-ww") do
      sign_in_rp_cell("base-app-ww", actor:, root_token:)
      get "/accounts", params: { ri: "jp" }

      assert_response :redirect
      assert_equal "/selector", URI.parse(response.location).path

      get base_app_identity_path(ri: "jp")

      assert_response :success

      get base_app_preference_path(ri: "jp")

      assert_response :success

      patch base_app_preference_region_path(ri: "jp"),
            params: { preference_region: { option_id: "US" }, actor_id: other_actor.id }

      assert_response :redirect
      assert_includes response.location, "/preference/region"

      browser_registry = PreferenceClassRegistry.fetch("App")
      account_registry = PreferenceClassRegistry.fetch("Client")
      notification_state_models = [
        browser_registry.fetch(:preference), browser_registry.fetch(:status), browser_registry.fetch(:cookie),
        browser_registry.fetch(:audit), browser_registry.fetch(:audit_event), browser_registry.fetch(:audit_level),
        *browser_registry.fetch(:option_classes).values, *browser_registry.fetch(:record_classes).values,
        AppPreferenceBrowserBinding, AppPreferenceConsentReceipt, AppPreferenceWebPush,
        account_registry.fetch(:preference), ClientPreferenceStatus,
        *account_registry.fetch(:option_classes).values, *account_registry.fetch(:record_classes).values,
        ClientEmail,
      ].uniq
      before_notification_state =
        notification_state_models.to_h do |model|
          [model.name, model.order(model.primary_key).pluck(*model.column_names)]
        end

      patch base_app_preference_notification_path(ri: "jp"),
            params: { preference_notification: { email: "daily", web_push: "enabled", unknown: "ignored" } }

      assert_response :see_other
      assert_redirected_to edit_base_app_preference_notification_path(ri: "jp")
      after_notification_state =
        notification_state_models.to_h do |model|
          [model.name, model.order(model.primary_key).pluck(*model.column_names)]
        end

      assert_equal before_notification_state, after_notification_state
    end

    token = cookies[PreferenceCookieName.anonymous_jwt]
    public_id = PreferenceToken.extract_public_id(PreferenceToken.decode(token, host:))
    browser_preference = AppPreference.find_by!(public_id:)

    assert_equal AppPreferenceRegionOption::US,
                 AppPreferenceRegion.find_by!(preference_id: browser_preference.id).option_id

    preference = ClientPreference.find_by!(client_id: actor.id)
    region = ClientPreferenceRegion.find_by!(preference_id: preference.id)

    assert_equal ClientPreferenceRegionOption::US, region.option_id
    assert_nil ClientPreference.find_by(client_id: other_actor.id)
  end

  test "Base ORG account preference writes resolve the verified Base cell subject in Zenith" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    actor = operators(:one)
    other_actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    root_token = authentication_harness_create_token(actor)
    host! host
    https!

    as_rp_cell("base-org-ww") do
      sign_in_rp_cell("base-org-ww", actor:, root_token:)
      get base_org_identity_path(ri: "jp")

      assert_response :success

      get base_org_preference_path(ri: "jp")

      assert_response :success

      patch base_org_preference_region_path(ri: "jp"),
            params: { preference_region: { option_id: "US" }, actor_id: other_actor.id }

      assert_response :redirect
      assert_includes response.location, "/preference/region"

      browser_registry = PreferenceClassRegistry.fetch("Org")
      account_registry = PreferenceClassRegistry.fetch("Operator")
      notification_state_models = [
        browser_registry.fetch(:preference), browser_registry.fetch(:status), browser_registry.fetch(:cookie),
        browser_registry.fetch(:audit), browser_registry.fetch(:audit_event), browser_registry.fetch(:audit_level),
        *browser_registry.fetch(:option_classes).values, *browser_registry.fetch(:record_classes).values,
        OrgPreferenceBrowserBinding, OrgPreferenceConsentReceipt, OrgPreferenceWebPush,
        account_registry.fetch(:preference), OperatorPreferenceStatus,
        *account_registry.fetch(:option_classes).values, *account_registry.fetch(:record_classes).values,
        OperatorEmail,
      ].uniq
      before_notification_state =
        notification_state_models.to_h do |model|
          [model.name, model.order(model.primary_key).pluck(*model.column_names)]
        end

      patch base_org_preference_notification_path(ri: "jp"),
            params: { preference_notification: { email: "daily", web_push: "enabled", unknown: "ignored" } }

      assert_response :see_other
      assert_redirected_to edit_base_org_preference_notification_path(ri: "jp")
      after_notification_state =
        notification_state_models.to_h do |model|
          [model.name, model.order(model.primary_key).pluck(*model.column_names)]
        end

      assert_equal before_notification_state, after_notification_state
    end

    token = cookies[PreferenceCookieName.anonymous_jwt]
    public_id = PreferenceToken.extract_public_id(PreferenceToken.decode(token, host:))
    browser_preference = OrgPreference.find_by!(public_id:)

    assert_equal OrgPreferenceRegionOption::US,
                 OrgPreferenceRegion.find_by!(preference_id: browser_preference.id).option_id

    preference = OperatorPreference.find_by!(operator_id: actor.id)
    region = OperatorPreferenceRegion.find_by!(preference_id: preference.id)

    assert_equal OperatorPreferenceRegionOption::US, region.option_id
    assert_nil OperatorPreference.find_by(operator_id: other_actor.id)
  end

  test "Base APP reset retires both Preference rows, issues shared cookies, and clears the binding cookie" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = clients(:one)
    root_token = authentication_harness_create_token(actor)
    host! host
    https!

    as_rp_cell("base-app-ww") do
      sign_in_rp_cell("base-app-ww", actor:, root_token:)
      get base_app_preference_path(ri: "jp")

      assert_response :success

      patch base_app_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: "dr" } }

      assert_response :redirect
      old_token = cookies[PreferenceCookieName.anonymous_jwt]
      old_claims = PreferenceToken.decode(old_token, host:, jwt_issuer_id: "preference_app")
      old_anonymous = AppPreference.find_by!(public_id: old_claims.fetch("sub"))
      account_preference = ClientPreference.find_by!(client_id: actor.id)
      cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value

      delete base_app_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" }

      assert_response :see_other
      new_token = cookies[PreferenceCookieName.anonymous_jwt]
      new_claims = PreferenceToken.decode(new_token, host:, jwt_issuer_id: "preference_app")
      new_anonymous = AppPreference.find_by!(public_id: new_claims.fetch("sub"))
      cookie_headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }

      assert_not_equal old_anonymous.id, new_anonymous.id
      assert_equal AppPreferenceStatus::RETIRED, old_anonymous.reload.status_id
      assert_equal AppPreferenceStatus::ACTIVE, new_anonymous.status_id
      assert_equal ClientPreferenceStatus::RETIRED, account_preference.reload.status_id
      [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
       PreferenceCookieName.anonymous_experience,].each do |name|
        assert cookie_headers.any? { |header| header.start_with?("#{name}=") }, "Missing cookie header for #{name}"
      end
      binding_header =
        cookie_headers.find do |header|
          header.start_with?("#{PreferenceBrowserBinding::COOKIE_NAME}=")
        end

      assert_not_nil binding_header
      assert_operator Time.httpdate(binding_header.match(/expires=([^;]+)/i)[1]), :<, Time.current
      assert_no_match(/\bdomain=/i, binding_header)
      assert_empty cookies[PreferenceBrowserBinding::COOKIE_NAME].to_s
      assert_equal AppPreferenceThemeOption::SYSTEM,
                   AppPreferenceTheme.find_by!(preference_id: new_anonymous.id).option_id
    end
  end

  test "Base ORG reset retires both Preference rows, issues shared cookies, and clears the binding cookie" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    actor = operators(:one)
    root_token = authentication_harness_create_token(actor)
    host! host
    https!

    as_rp_cell("base-org-ww") do
      sign_in_rp_cell("base-org-ww", actor:, root_token:)
      get base_org_preference_path(ri: "jp")

      assert_response :success

      patch base_org_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: "dr" } }

      assert_response :redirect
      old_token = cookies[PreferenceCookieName.anonymous_jwt]
      old_claims = PreferenceToken.decode(old_token, host:, jwt_issuer_id: "preference_org")
      old_anonymous = OrgPreference.find_by!(public_id: old_claims.fetch("sub"))
      account_preference = OperatorPreference.find_by!(operator_id: actor.id)
      cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value

      delete base_org_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" }

      assert_response :see_other
      new_token = cookies[PreferenceCookieName.anonymous_jwt]
      new_claims = PreferenceToken.decode(new_token, host:, jwt_issuer_id: "preference_org")
      new_anonymous = OrgPreference.find_by!(public_id: new_claims.fetch("sub"))
      cookie_headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }

      assert_not_equal old_anonymous.id, new_anonymous.id
      assert_equal OrgPreferenceStatus::RETIRED, old_anonymous.reload.status_id
      assert_equal OrgPreferenceStatus::ACTIVE, new_anonymous.status_id
      assert_equal OperatorPreferenceStatus::RETIRED, account_preference.reload.status_id
      [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
       PreferenceCookieName.anonymous_experience,].each do |name|
        assert cookie_headers.any? { |header| header.start_with?("#{name}=") }, "Missing cookie header for #{name}"
      end
      binding_header =
        cookie_headers.find do |header|
          header.start_with?("#{PreferenceBrowserBinding::COOKIE_NAME}=")
        end

      assert_not_nil binding_header
      assert_operator Time.httpdate(binding_header.match(/expires=([^;]+)/i)[1]), :<, Time.current
      assert_no_match(/\bdomain=/i, binding_header)
      assert_empty cookies[PreferenceBrowserBinding::COOKIE_NAME].to_s
      assert_equal OrgPreferenceThemeOption::SYSTEM,
                   OrgPreferenceTheme.find_by!(preference_id: new_anonymous.id).option_id
    end
  end
end
