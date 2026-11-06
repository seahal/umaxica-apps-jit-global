# frozen_string_literal: true

require "test_helper"
require_relative "../support/oidc_auth_admission_test_helper"

class OrgEntryCancellationJourneyTest < ActionDispatch::IntegrationTest
  include OidcAuthAdmissionTestHelper

  self.fixture_table_names = []

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    @visa_host = visa_host_for_test_surface(:org)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
  end

  [
    ["method selection", "/sign/in", "cancel_form"],
    ["emergency Passkey", "/sign/in/emergency/passkey/new", "parent_cancel"],
  ].each do |label, path, cancel_key|
    test "ORG #{label} Cancel protects CSRF and reaches Base interruption through Visa" do
      bootstrap_auth_sign_in_admission!(surface: "org")
      get(path, params: { ri: "jp" }, headers: navigation_headers(site: "same-origin"))

      assert_response :success
      cancel = inertia_props.fetch(cancel_key)
      if cancel_key == "parent_cancel"
        assert_equal I18n.t("actions.back"), inertia_props.fetch("back_link").fetch("label")
        assert_equal "/sign/in", URI.parse(inertia_props.fetch("back_link").fetch("href")).path
      end

      assert_predicate cancel, :present?
      assert_equal "/sign/cancellation", URI.parse(cancel.fetch("action")).path
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      ceremony = OperatorAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name])
      parent = OperatorOidcAuthorizationTransaction.find_by!(transaction_id: ceremony.authorization_transaction_ref)
      before = [ceremony.attributes, parent.attributes]
      token_count = OperatorToken.count
      headers = navigation_headers(site: "same-origin").merge("Origin" => "https://#{@auth_host}")
      post(cancel.fetch("action"), headers: headers)

      assert_response :unprocessable_content
      assert_equal before, [ceremony.reload.attributes, parent.reload.attributes]
      post(cancel.fetch("action"), params: { authenticity_token: csrf }, headers: headers)

      assert_response :see_other
      assert_predicate ceremony.reload, :cancelled?
      assert_predicate parent.reload, :canceled?
      assert_predicate cookies[cookie_name], :blank?
      assert_visa_cancellation_and_base_interruption
      assert_equal token_count, OperatorToken.count
    end
  end

  private

  def assert_visa_cancellation_and_base_interruption
    visa = follow_admission_redirects!(
      base_host: @base_host, visa_host: @visa_host, auth_host: @auth_host, browser: self,
    )

    assert_equal @visa_host, visa.host
    assert_equal 200, visa.response.status
    form = visa.response.parsed_body.at_css("form#visa-authorization-continuation-form")

    assert form, "Visa must render the cancellation continuation POST"
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    visa.post(
      form["action"], params: fields,
                      headers: navigation_headers(site: "same-origin").merge("Origin" => "https://#{@visa_host}"),
    )

    assert_equal 303, visa.response.status
    callback = URI.parse(jump_rt_url_from_location_for_test(visa.response.location))
    query = Rack::Utils.parse_query(callback.query)

    assert_equal @base_host, callback.host
    assert_equal "/oidc/callback", callback.path
    assert_equal "access_denied", query.fetch("error")
    assert_not query.key?("code")
    base = follow_admission_redirects!(
      base_host: @base_host, visa_host: @visa_host, auth_host: @auth_host, browser: visa,
    )

    assert_equal @base_host, base.host
    assert_equal "/sign/interruption", base.request.path
    assert_equal 200, base.response.status
    assert_nil base.response.location
  end
end
