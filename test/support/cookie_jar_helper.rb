# frozen_string_literal: true

module CookieJarHelper
  # `Rack::Test::CookieJar#merge` stores the cookies in the jar it is called on, unlike `Hash#merge`.
  # Lint/Void goes by the method name, so a bare `cookies.merge(...)` whose result is unused reads to
  # it as a discarded value. Routing the call through a method that names the effect keeps that check
  # on for real hashes.
  def store_raw_cookies(jar, raw_cookies, uri = nil)
    jar.merge(raw_cookies, uri)
  end
end
