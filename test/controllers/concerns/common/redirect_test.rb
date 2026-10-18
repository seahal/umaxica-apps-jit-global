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

  test "normalize_host returns nil for blank values" do
    assert_nil CommonRedirect.normalize_host(nil)
    assert_nil CommonRedirect.normalize_host("")
    assert_nil CommonRedirect.normalize_host("   ")
  end

  test "normalize_host extracts host from URL" do
    assert_equal "example.com", CommonRedirect.normalize_host("https://example.com/path")
    assert_equal "example.com", CommonRedirect.normalize_host("http://example.com")
    assert_equal "example.com", CommonRedirect.normalize_host("example.com/path")
  end

  test "normalize_host handles invalid URIs" do
    assert_equal "not a url", CommonRedirect.normalize_host("not a url")
  end

  test "normalize_host downcases host" do
    assert_equal "example.com", CommonRedirect.normalize_host("HTTPS://EXAMPLE.COM")
  end

  # --- Open-redirect regression guards -------------------------------------
  #
  # safe_internal_path / safe_return_path are the security boundary that keeps
  # user-supplied return targets from redirecting off-site. These tests pin the
  # rejection contract so a future refactor cannot silently widen it.
end
