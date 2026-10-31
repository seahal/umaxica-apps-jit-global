# frozen_string_literal: true

require "test_helper"

class AnonymousComConsentReceiptTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "explicit acceptance and refusal record distinct consent decision versions" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    decision_time = ComPreference.database_now.change(usec: 0)
    ComPreference.stub(:database_now, decision_time) do
      patch base_com_api_v0_preferences_cookie_path, params: { consented: true }.to_json, headers: headers
    end

    assert_response :ok
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
    receipt = ComPreferenceConsentReceipt.find_by!(preference_id: preference.id)
    version = receipt.version

    assert_match(/\A[0-9a-f-]{36}\z/, version)
    assert_equal decision_time, receipt.recorded_at
    assert_predicate ComPreferenceCookie.find_by!(preference_id: preference.id), :functional?
    ComPreference.stub(:database_now, decision_time + 1.second) do
      patch base_com_api_v0_preferences_cookie_path, params: { consented: false }.to_json, headers: headers
    end

    assert_response :ok
    assert_equal 1, ComPreferenceConsentReceipt.where(preference_id: preference.id).count
    assert_not_equal version, receipt.reload.version
    assert_equal decision_time + 1.second, receipt.recorded_at
    assert_not ComPreferenceCookie.find_by!(preference_id: preference.id).functional?
  end

  test "web push alone does not create a consent decision receipt" do
    host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    https!
    patch base_com_api_v0_preferences_web_push_path,
          params: { web_push: "enabled" }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :ok
    claims = PreferenceToken.decode(
      cookies[PreferenceCookieName.anonymous_jwt],
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
    )
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))

    assert_not ComPreferenceConsentReceipt.exists?(preference_id: preference.id)
  end

  test "an explicit refusal differs from an unanswered consent request" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")
    patch base_com_api_v0_preferences_cookie_path, params: { consented: false }.to_json, headers: headers

    assert_response :ok
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
    cookie = ComPreferenceCookie.find_by!(preference_id: preference.id)

    assert_predicate ComPreferenceConsentReceipt.where(preference_id: preference.id), :exists?
    assert_not cookie.consented?
    assert_not cookie.functional?
    assert_not cookie.performant?
    assert_not cookie.targetable?
    get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_not response.parsed_body.fetch("show_banner")
    get edit_base_com_preference_cookie_path(ri: "jp")

    assert_response :ok
    categories = JSON.parse(response.parsed_body.at_css("script[data-page]").text)
      .fetch("props").fetch("form").fetch("categories")

    assert_not categories.find { |category| category.fetch("key") == "consented" }.fetch("value")
    assert categories.reject { |category| category.fetch("key") == "consented" }
      .none? { |category| category.fetch("value") }
    cookies.delete(PreferenceBrowserBinding::COOKIE_NAME)
    get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")
  end

  test "a receipt lookup failure does not hide the consent banner" do
    host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    https!
    patch base_com_api_v0_preferences_cookie_path,
          params: { consented: false }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :ok
    failure = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "receipt unavailable" }
    ComPreferenceConsentReceipt.stub(:exists?, failure) do
      get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }
    end

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")
  end

  test "a bound positive cookie without a receipt is not treated as consent" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_cookie_path, params: { consented: true }.to_json, headers: headers

    assert_response :ok
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
    ComPreferenceConsentReceipt.find_by!(preference_id: preference.id).destroy!
    get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")
    assert_predicate ComPreferenceCookie.find_by!(preference_id: preference.id), :consented?
  end

  test "an explicit refusal replaces unbound legacy consent without trusting it" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json, headers: headers

    assert_response :ok
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
    cookie = ComPreferenceCookie.find_by!(preference_id: preference.id)
    cookie.update!(consented: true, functional: true, performant: true, targetable: true)

    assert_not ComPreferenceConsentReceipt.exists?(preference_id: preference.id)
    assert_not ComPreferenceBrowserBinding.exists?(preference_id: preference.id)
    patch base_com_api_v0_preferences_cookie_path, params: { consented: false }.to_json, headers: headers

    assert_response :ok
    assert_predicate ComPreferenceConsentReceipt.where(preference_id: preference.id), :exists?
    assert_predicate ComPreferenceBrowserBinding.where(preference_id: preference.id), :exists?
    assert_not cookie.reload.functional?
    assert_not cookie.performant?
    assert_not cookie.targetable?
  end

  test "binding an unrecorded legacy choice for web push does not grant consent" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json, headers: headers

    assert_response :ok
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
    cookie = ComPreferenceCookie.find_by!(preference_id: preference.id)
    cookie.update!(consented: true, functional: true, performant: true, targetable: true)
    patch base_com_api_v0_preferences_web_push_path, params: { web_push: "enabled" }.to_json, headers: headers

    assert_response :ok
    assert_not ComPreferenceConsentReceipt.exists?(preference_id: preference.id)
    get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")
    get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal "enabled", response.parsed_body.fetch("web_push")
  end

  test "a partial screen save does not promote unrecorded legacy consent flags" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    [false, true].each do |existing_binding|
      reset!
      host! host
      https!
      patch base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json, headers: headers

      assert_response :ok
      if existing_binding
        patch base_com_api_v0_preferences_web_push_path, params: { web_push: "enabled" }.to_json, headers: headers

        assert_response :ok
      end
      claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
      preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
      cookie = ComPreferenceCookie.find_by!(preference_id: preference.id)
      cookie.update!(consented: true, functional: true, performant: true, targetable: true)

      assert_not ComPreferenceConsentReceipt.exists?(preference_id: preference.id)
      patch base_com_preference_cookie_path(ri: "jp"), params: { preference_cookie: { functional: "false" } }

      assert_response :see_other
      assert_predicate ComPreferenceConsentReceipt.where(preference_id: preference.id), :exists?
      cookie.reload

      assert_not cookie.consented?
      assert_not cookie.functional?
      assert_not cookie.performant?
      assert_not cookie.targetable?
    end
  end

  test "a partial screen save preserves other recorded consent choices" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_api_v0_preferences_cookie_path,
          params: { consented: true }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :ok
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
    receipt = ComPreferenceConsentReceipt.find_by!(preference_id: preference.id)
    old_version = receipt.version
    patch base_com_preference_cookie_path(ri: "jp"), params: { preference_cookie: { functional: "false" } }

    assert_response :see_other
    cookie = ComPreferenceCookie.find_by!(preference_id: preference.id)

    assert_not cookie.functional?
    assert_predicate cookie, :consented?
    assert_predicate cookie, :performant?
    assert_predicate cookie, :targetable?
    assert_not_equal old_version, receipt.reload.version
  end

  test "a partial JSON screen save returns the complete recorded choices" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_api_v0_preferences_cookie_path,
          params: { consented: true }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :ok
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { functional: "false" } },
          headers: { "Accept" => "application/json" }

    assert_response :ok
    result = response.parsed_body.fetch("preference")

    assert result.fetch("consented")
    assert_not result.fetch("functional")
    assert result.fetch("performant")
    assert result.fetch("targetable")
    get edit_base_com_preference_cookie_path(ri: "jp")

    assert_response :ok
    categories = JSON.parse(response.parsed_body.at_css("script[data-page]").text)
      .fetch("props").fetch("form").fetch("categories")

    categories.each do |category|
      assert_equal result.fetch(category.fetch("key")), category.fetch("value")
    end
  end

  test "the first partial JSON screen save returns its newly bound choice" do
    host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    https!
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { functional: "true" } },
          headers: { "Accept" => "application/json" }

    assert_response :ok
    result = response.parsed_body.fetch("preference")

    assert result.fetch("functional")
    assert_not result.fetch("consented")
    assert_not result.fetch("performant")
    assert_not result.fetch("targetable")
    assert_predicate cookies[PreferenceBrowserBinding::COOKIE_NAME], :present?
  end

  test "a signing failure rolls back the explicit consent decision and its receipt" do
    host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    https!

    PreferenceToken.stub(:encode, nil) do
      assert_no_difference -> { ComPreferenceConsentReceipt.count } do
        assert_no_difference -> { ComPreference.count } do
          patch base_com_api_v0_preferences_cookie_path,
                params: { consented: true }.to_json,
                headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
        end
      end
    end

    assert_response :service_unavailable
  end

  test "a signing failure rolls back a change to an existing consent receipt" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_cookie_path, params: { consented: true }.to_json, headers: headers

    assert_response :ok
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
    receipt = ComPreferenceConsentReceipt.find_by!(preference_id: preference.id)
    previous_receipt = receipt.attributes
    previous_cookie = ComPreferenceCookie.find_by!(preference_id: preference.id).attributes
    PreferenceToken.stub(:encode, nil) do
      patch base_com_api_v0_preferences_cookie_path, params: { consented: false }.to_json, headers: headers
    end

    assert_response :service_unavailable
    assert_equal previous_receipt, receipt.reload.attributes
    assert_equal previous_cookie, ComPreferenceCookie.find_by!(preference_id: preference.id).attributes
  end
end
