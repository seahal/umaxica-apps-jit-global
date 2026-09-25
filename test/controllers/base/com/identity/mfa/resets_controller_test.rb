# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Identity::Mfa::ResetsControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    @visitor = visitors(:reserved_visitor)
    @visitor.update!(mfa_level_id: VisitorMfaLevel::FULL, mfa_level_enabled: true)
    @headers = as_visitor_headers(@visitor, host: @host)
    @token = VisitorToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
  end

  test "show is a GET-only unavailable placeholder that leaves security state unchanged" do
    before = security_state

    get base_com_identity_mfa_reset_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_predicate inertia_props.fetch("reset_unavailable"), :present?
    assert_equal before, security_state
  end

  test "mutation verbs are not routes and change no security state" do
    before = security_state
    path = base_com_identity_mfa_reset_url(ri: "jp", host: @host)

    %i(post patch put delete).each do |method|
      process(method, path, headers: @headers)

      assert_response :not_found, method.to_s
    end

    assert_equal before, security_state
  end

  private

  def security_state
    {
      visitor: @visitor.reload.attributes,
      session: @token.reload.attributes,
      credentials: [@visitor.visitor_secret_credentials.count, @visitor.visitor_passkeys.count],
      chronicles: [
        Chronicle.where(actor_type: "Visitor", actor_id: @visitor.id).count,
        Chronicle.where(subject_type: "Visitor", subject_id: @visitor.id).count,
        ClientChronicle.where(actor_type: "Visitor", actor_id: @visitor.id).count,
        ClientChronicle.where(subject_type: "Visitor", subject_id: @visitor.id.to_s).count,
      ],
    }
  end
end
