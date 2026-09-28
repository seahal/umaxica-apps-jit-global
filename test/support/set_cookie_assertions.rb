# typed: false
# frozen_string_literal: true

# Reads the response's Set-Cookie header lines directly. The Rack::Test jar keeps an expired cookie
# as "" instead of dropping it, so `cookies[name]` cannot tell a browser-effective deletion from a
# cookie set to an empty value. A browser replaces a stored cookie only when name, domain (or its
# absence, host-only), and path match, and removes it when Max-Age is 0 or Expires is in the past.
module SetCookieAssertions
  IDENTITY_ATTRIBUTES = %i(path domain secure samesite partitioned).freeze

  def set_cookie_entries(name)
    Array(response.headers["set-cookie"]).flat_map { |header| header.to_s.split("\n") }.filter_map do |line|
      pair, *attributes = line.split(/;\s*/)
      cookie_name, value = pair.split("=", 2)
      next unless cookie_name == name

      attributes.each_with_object({ value: value.to_s }) do |attribute, entry|
        key, attribute_value = attribute.split("=", 2)
        entry[key.downcase.to_sym] = attribute_value.nil? || attribute_value.downcase
      end
    end
  end

  def host_only_set_cookie(name)
    entries = set_cookie_entries(name).reject { |entry| entry.key?(:domain) }

    assert_equal 1, entries.size, "expected one host-only Set-Cookie for #{name}, got #{entries.inspect}"
    entries.first
  end

  def assert_cookie_deleted(name, issued: nil)
    entry = host_only_set_cookie(name)

    assert_equal "", entry[:value], "#{name} deletion must carry an empty value"
    assert(
      entry[:"max-age"] == "0" || (entry[:expires] && Time.httpdate(entry[:expires]) < Time.current),
      "#{name} deletion must expire the cookie: #{entry.inspect}",
    )
    return entry unless issued

    assert_equal issued.slice(*IDENTITY_ATTRIBUTES), entry.slice(*IDENTITY_ATTRIBUTES),
                 "#{name} deletion must match the issued cookie's identity attributes"
    entry
  end

  def assert_cookie_issued(name)
    entry = host_only_set_cookie(name)

    assert_predicate entry[:value], :present?, "#{name} must be issued with a value"
    assert_equal "/", entry[:path]
    assert_equal "strict", entry[:samesite]
    assert entry[:httponly], "#{name} must be HttpOnly"
    entry
  end

  def assert_no_set_cookie(name)
    assert_empty set_cookie_entries(name), "#{name} must not be written by this response"
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include SetCookieAssertions }
