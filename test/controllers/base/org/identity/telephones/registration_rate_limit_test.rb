# typed: false
# frozen_string_literal: true

require "test_helper"

# Starting a telephone verification sends an SMS, so the start step is throttled per client
# address: SignOperatorTelephoneRegistrable allows TELEPHONE_VERIFICATION_RATE_LIMIT starts per
# window and answers the next one 429 without creating another pending telephone.
class Base::Org::Identity::Telephones::RegistrationRateLimitTest < ActionDispatch::IntegrationTest
  rate_limit_counters!

  fixtures :operators, :operator_statuses, :operator_telephone_statuses,
           :operator_token_kinds, :operator_token_statuses, :operator_token_binding_methods,
           :operator_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @operator = operators(:one)
    @token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    _verification, raw_verification = OperatorVerification.issue_for_token!(token: @token)
    cookies[OperatorVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    access_token = AuthenticationToken.encode(
      @operator, host: @host, session_public_id: @token.public_id,
                 resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze

    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the start step is refused once the per-address window limit is passed" do
    Rails.configuration.x.rate_limit.fetch(:store).clear
    limit = SignOperatorTelephoneRegistrable::TELEPHONE_VERIFICATION_RATE_LIMIT

    limit.times do |index|
      post(
        base_org_identity_telephones_registration_url(ri: "jp", host: @host),
        params: { staff_telephone: { raw_number: "+1555867#{format("%04d", 5400 + index)}" } }, headers: @headers,
      )

      assert_not_equal 429, response.status, "start #{index + 1} of #{limit} was refused"
    end

    assert_no_difference("OperatorTelephone.count") do
      post(
        base_org_identity_telephones_registration_url(ri: "jp", host: @host),
        params: { staff_telephone: { raw_number: "+15558675499" } }, headers: @headers,
      )
    end

    assert_response :too_many_requests
  ensure
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end
end
