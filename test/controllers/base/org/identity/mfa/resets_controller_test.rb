# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Identity::Mfa::ResetsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @operator = operators(:one)
    @operator.update!(mfa_level_id: OperatorMfaLevel::FULL, mfa_level_enabled: true)
    @headers = as_staff_headers(@operator, host: @host)
    @token = OperatorToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
  end

  test "show is a GET-only unavailable placeholder that leaves security state unchanged" do
    before = security_state

    get base_org_identity_mfa_reset_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_predicate inertia_props.fetch("reset_unavailable"), :present?
    assert_equal before, security_state
  end

  test "mutation verbs are not routes and change no security state" do
    before = security_state
    path = base_org_identity_mfa_reset_url(ri: "jp", host: @host)

    %i(post patch put delete).each do |method|
      process(method, path, headers: @headers)

      assert_response :not_found, method.to_s
    end

    assert_equal before, security_state
  end

  private

  def security_state
    {
      operator: @operator.reload.attributes,
      session: @token.reload.attributes,
      credentials: [@operator.staff_secret_credentials.count, @operator.operator_passkeys.count],
      chronicles: [
        Chronicle.where(actor_type: "Operator", actor_id: @operator.id).count,
        Chronicle.where(subject_type: "Operator", subject_id: @operator.id).count,
        OperatorChronicle.where(actor_type: "Operator", actor_id: @operator.id).count,
        OperatorChronicle.where(subject_type: "Operator", subject_id: @operator.id.to_s).count,
      ],
    }
  end
end
