# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthCeremonySidCookieTest < ActiveSupport::TestCase
  test "cookie helper exposes host-prefixed random-only name in secure context" do
    assert_equal "auth_sid", AuthCeremonySidCookie::COOKIE_BASENAME
    source = Rails.root.join("app/controllers/concerns/auth_ceremony_sid_cookie.rb").read

    assert_match(/secure: JitSessionCookieConfig\.force_secure\?/, source)
    assert_match(/httponly: true/, source)
    assert_match(/HOST_COOKIE_PREFIX/, source)
    body = source.split("module AuthCeremonySidCookie", 2).last

    assert_no_match(/access_token|id_token|aal\b/i, body)
  end
end
