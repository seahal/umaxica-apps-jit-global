# typed: false
# frozen_string_literal: true

require "test_helper"

module Preference
  class CookieNameTest < ActiveSupport::TestCase
    test "uses one realm shared JWT and display pair with a separate host only binding" do
      assert_equal "__Secure-preference", PreferenceCookieName.anonymous_jwt
      assert_equal "language", PreferenceIoKeys::Cookies::LANGUAGE
      assert_equal "__Secure-experience", PreferenceCookieName.anonymous_experience
      assert_equal "__Host-preference_binding", PreferenceCookieName.binding

      assert_equal 4, [
        PreferenceCookieName.anonymous_jwt,
        PreferenceIoKeys::Cookies::LANGUAGE,
        PreferenceCookieName.anonymous_experience,
        PreferenceCookieName.binding,
      ].uniq.length
    end
  end
end
