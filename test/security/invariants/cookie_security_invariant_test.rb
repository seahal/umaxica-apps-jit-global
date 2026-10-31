# frozen_string_literal: true

require "test_helper"

class PreferenceSecurityInvariantController < ApplicationController
  include PreferenceBase

  def test_anonymous_cookie_options(expires_at:, httponly:)
    anonymous_com_cookie_options(expires_at:, httponly:)
  end
end

module Security
  module Invariants
    class CookieSecurityInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "preference transport has one shared JWT, two display cookies, and a host only binding" do
        assert_equal "__Secure-preference", PreferenceCookieName.anonymous_jwt
        assert_equal "language", PreferenceIoKeys::Cookies::LANGUAGE
        assert_equal "__Secure-experience", PreferenceCookieName.anonymous_experience
        assert_equal "__Host-preference_binding", PreferenceBrowserBinding::COOKIE_NAME
      end

      test "shared preference JWT and display cookies are secure and scoped to their realm domain" do
        controller = PreferenceSecurityInvariantController.new
        controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.example")
        controller.response = ActionDispatch::TestResponse.new

        http_only = controller.test_anonymous_cookie_options(expires_at: 10.minutes.from_now, httponly: true)
        display = controller.test_anonymous_cookie_options(expires_at: 10.minutes.from_now, httponly: false)

        assert http_only[:secure]
        assert http_only[:httponly]
        assert_equal ".app.example", http_only[:domain]
        assert_equal :lax, http_only[:same_site]
        assert display[:secure]
        assert_not display[:httponly]
        assert_equal http_only[:domain], display[:domain]
      end

      test "browser binding is host only and HttpOnly" do
        request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.example")

        options = CoreCookieOptions.for(
          request:, httponly: true, secure: true, same_site: :lax, path: "/",
        )

        assert options[:secure]
        assert options[:httponly]
        assert_equal :lax, options[:same_site]
        assert_equal "/", options[:path]
        assert_not options.key?(:domain)
      end
    end
  end
end
