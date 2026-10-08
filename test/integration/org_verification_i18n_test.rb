# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgVerificationI18nTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PRIVATE_AUTH_STAFF_URL")
    host! @host
    OrgZenithRecord.connected_to(role: :writing) do
      OperatorStatus.insert_missing_fixed_ids!(
        [OperatorStatus::ACTIVE,
         OperatorStatus::NOTHING, OperatorStatus::RESERVED,],
      )
    end

    @staff = Operator.create!(status_id: OperatorStatus::NOTHING, public_id: Operator.generate_public_id)
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      public_id: "ov_i18n_#{SecureRandom.hex(4)}",
      discard_at: 1.day.from_now,
    )
    @headers = as_staff_headers(
      @staff, host: @host, headers: browser_headers,
              session_public_id: @token.public_id,
    ).freeze

    OperatorPasskey.create!(
      staff: @staff,
      description: "verify i18n passkey",
      webauthn_id: "org-verify-i18n-#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
  end

  test "verification view displays translated strings in Japanese" do
    OperatorStepUpSession.delete_all

    get auth_org_verification_url(ri: "jp"), headers: @headers

    assert_response :success
    # The headings arrive as props and the React page renders them, so the translated strings the
    # server chose for this locale are what the page object carries.
    assert_equal I18n.t("sign.org.verification.index.title", locale: :ja), inertia_props.fetch("title")
    assert_equal I18n.t("sign.org.verification.new.title", locale: :ja), inertia_props.fetch("section_title")
  end

  test "verification view displays translated strings in English" do
    OperatorStepUpSession.delete_all

    get auth_org_verification_url(ri: "us", lx: "en"), headers: @headers

    assert_response :success
    # The headings arrive as props and the React page renders them, so the translated strings the
    # server chose for this locale are what the page object carries.
    assert_equal I18n.t("sign.org.verification.index.title", locale: :en), inertia_props.fetch("title")
    assert_equal I18n.t("sign.org.verification.new.title", locale: :en), inertia_props.fetch("section_title")
  end
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end

# DAMP auth header helpers for this test class.
class OrgVerificationI18nTest
  private
end
