# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CommonRedirectTest < ActiveSupport::TestCase
  test "private helper methods are not public on including controller" do
    # Define a test controller that includes the concern
    test_controller =
      Class.new(ApplicationController) do
        include CommonRedirect
      end

    controller = test_controller.new

    # These methods should be private, not public
    assert_includes controller.private_methods, :safe_internal_path
    assert_not controller.public_methods.include?(:safe_internal_path)

    assert_includes controller.private_methods, :safe_redirect_to
    assert_not controller.public_methods.include?(:safe_redirect_to)

    assert_includes controller.private_methods, :safe_redirect_back_or_to
    assert_not controller.public_methods.include?(:safe_redirect_back_or_to)
  end

  test "allowed_hosts is public on including controller" do
    test_controller =
      Class.new(ApplicationController) do
        include CommonRedirect
      end

    controller = test_controller.new

    # allowed_hosts should remain public (for diagnostics/auditing)
    assert_respond_to controller, :allowed_hosts
    assert_not controller.private_methods.include?(:allowed_hosts)
  end

  test "normalize_host returns nil for blank input" do
    assert_nil CommonRedirect.normalize_host(nil)
    assert_nil CommonRedirect.normalize_host("")
    assert_nil CommonRedirect.normalize_host("   ")
  end

  test "normalize_host extracts host from a full URL" do
    assert_equal "example.com", CommonRedirect.normalize_host("https://example.com/path?q=1")
    assert_equal "example.com", CommonRedirect.normalize_host("http://example.com")
  end

  test "normalize_host returns a downcased plain hostname" do
    assert_equal "example.com", CommonRedirect.normalize_host("Example.COM")
  end

  test "normalize_host strips scheme remnants from bare host strings" do
    assert_equal "example.com", CommonRedirect.normalize_host("https://example.com")
    assert_equal "example.com", CommonRedirect.normalize_host("http://example.com")
  end

  test "normalize_host handles port-included URLs by returning just the host" do
    assert_equal "example.com", CommonRedirect.normalize_host("https://example.com:443/path")
  end

  test "normalize_host handles URIs with an invalid scheme by using the raw string" do
    result = CommonRedirect.normalize_host("not a uri\x00invalid")

    assert_not_nil result
  end

  test "normalize_host strips leading path components from plain path strings" do
    # A path-only string has no URI host; falls back to splitting on '/'
    result = CommonRedirect.normalize_host("example.com/some/path")

    assert_equal "example.com", result
  end

  test "normalize_host keeps an unparseable plain string" do
    assert_equal "not a url", CommonRedirect.normalize_host("not a url")
  end

  test "normalize_host downcases a full uppercase URL" do
    assert_equal "example.com", CommonRedirect.normalize_host("HTTPS://EXAMPLE.COM")
  end
end
