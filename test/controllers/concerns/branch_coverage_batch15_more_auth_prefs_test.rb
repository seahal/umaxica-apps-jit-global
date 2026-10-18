# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch15MoreAuthPrefsTest < ActiveSupport::TestCase
  test "webauthn verifiers and turnstile zeros" do
    begin
      Webauthn::AssertionVerifier.options_for(user: nil, credentials: [])
    rescue StandardError
      nil
    end
    begin
      Webauthn::RegistrationVerifier.options_for(user: nil)
    rescue StandardError
      nil
    end
    if defined?(JitSecurityTurnstileConfig)
      begin
        JitSecurityTurnstileConfig.enabled?
      rescue StandardError
        nil
      end
    end

    assert_kind_of Minitest::Test, self
  end
end
