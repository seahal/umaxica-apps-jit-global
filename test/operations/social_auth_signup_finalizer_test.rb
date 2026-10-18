# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthSignupFinalizerTest < ActiveSupport::TestCase
  test "rejects a signup callback without a verified external principal" do
    error =
      assert_raises(SocialAuth::ProviderError) do
        SocialAuthSignupFinalizer.call(
          principal: Object.new,
          credential_candidate: nil,
          birthdate: Date.new(2000, 1, 1),
          ceremony_started_at: Time.current,
        )
      end

    assert_equal "errors.social_auth.provider_error", error.i18n_key
    assert_equal :bad_request, error.status_code
  end
end
