# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreCookieOptionsTest < ActiveSupport::TestCase
  class MockRequest
    attr_reader :host, :ssl

    def initialize(host, ssl: false)
      @host = host
      @ssl = ssl
    end

    def ssl?
      @ssl
    end
  end

  test "for returns httponly and secure options" do
    request = MockRequest.new("wwww.example.com")

    options = CoreCookieOptions.for(request: request, secure: true)

    assert options[:httponly]
    assert options[:secure]
  end

  test "for includes same_site when provided" do
    request = MockRequest.new("wwww.example.com")

    options = CoreCookieOptions.for(request: request, same_site: :strict)

    assert_equal :strict, options[:same_site]
  end

  test "for includes expires when provided" do
    request = MockRequest.new("wwww.example.com")
    expires = 1.hour.from_now

    options = CoreCookieOptions.for(request: request, expires: expires)

    assert_equal expires, options[:expires]
  end

  test "for includes path when provided" do
    request = MockRequest.new("wwww.example.com")

    options = CoreCookieOptions.for(request: request, path: "/api")

    assert_equal "/api", options[:path]
  end

  test "for includes same_site lax when provided" do
    request = MockRequest.new("wwww.example.com")

    options = CoreCookieOptions.for(request: request, same_site: :lax)

    assert_equal :lax, options[:same_site]
  end

  test "for includes expires one year when provided" do
    request = MockRequest.new("wwww.example.com")
    expires = 1.year.from_now

    options = CoreCookieOptions.for(request: request, expires: expires)

    assert_equal expires, options[:expires]
  end

  test "for includes path accounts when provided" do
    request = MockRequest.new("wwww.example.com")

    options = CoreCookieOptions.for(request: request, path: "/accounts")

    assert_equal "/accounts", options[:path]
  end

  test "no environment sets a Domain or Partitioned attribute (D-58, D-115)" do
    request = MockRequest.new("www.umaxica.app", ssl: true)

    %w(development test production).each do |name|
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new(name)) do
        options = CoreCookieOptions.for(request: request, same_site: :strict, path: "/")

        assert_not options.key?(:domain), name
        assert_not options.key?(:partitioned), name
      end
    end
  end
end
