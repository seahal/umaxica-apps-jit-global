# typed: false
# frozen_string_literal: true

require "test_helper"

class Palm::App::Sign::Out::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")
    host! @host
    https!
  end

  test "an RP-facing logout challenge cannot complete a Palm sign-out" do
    get palm_app_sign_out_completion_path(logout_challenge: "forged-challenge", ri: "jp")

    assert_response :not_found
  end
end
