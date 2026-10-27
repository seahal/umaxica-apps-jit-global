# typed: false
# frozen_string_literal: true

require "test_helper"

class Tech::Org::Sign::Out::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
    https!
  end

  test "an RP-facing logout challenge cannot complete a Tech sign-out" do
    get tech_org_sign_out_completion_path(logout_challenge: "forged-challenge", ri: "jp")

    assert_response :not_found
  end
end
