# typed: false
# frozen_string_literal: true

require "test_helper"

# Passkey ceremony behavior lives under Auth::App::Verification and is covered by
# Auth::App::Verification::PasskeysControllerTest. The former general settings
# surface must remain absent rather than becoming an alias for Base management.
class Auth::App::Settings::PasskeysControllerTest < ActionDispatch::IntegrationTest
  test "retired passkey settings paths have no route or redirect" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    %w(
      /settings/passkeys
      /settings/passkeys/new
      /settings/passkeys/options
      /settings/passkeys/verification
      /settings/passkeys/1
    ).each do |path|
      get path

      assert_response :not_found, path
      assert_nil response.headers["Location"], path
    end
  end
end
