# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreHostNormalizationTest < ActiveSupport::TestCase
  test "normalize returns nil for blank string" do
    assert_nil CoreHostNormalization.normalize("")
  end

  test "normalize returns nil for nil" do
    assert_nil CoreHostNormalization.normalize(nil)
  end

  test "normalize returns nil for whitespace-only string" do
    assert_nil CoreHostNormalization.normalize("   ")
  end

  test "normalize downcases the host" do
    assert_equal "example.com", CoreHostNormalization.normalize("EXAMPLE.COM")
  end

  test "normalize strips whitespace" do
    assert_equal "example.com", CoreHostNormalization.normalize("  example.com  ")
  end

  test "normalize removes trailing dot" do
    assert_equal "example.com", CoreHostNormalization.normalize("example.com.")
  end

  test "normalize extracts host from URL" do
    assert_equal "example.com", CoreHostNormalization.normalize("https://example.com")
  end

  test "normalize handles plain host without scheme" do
    assert_equal "id.app.localhost", CoreHostNormalization.normalize("id.app.localhost")
  end

  test "normalize handles subdomain hosts" do
    assert_equal "sub.example.com", CoreHostNormalization.normalize("sub.example.com")
  end

  test "normalize removes port from URL" do
    assert_equal "example.com", CoreHostNormalization.normalize("https://example.com:443")
  end

  test "normalize handles localhost" do
    assert_equal "localhost", CoreHostNormalization.normalize("localhost")
  end

  test "normalize handles http scheme" do
    assert_equal "example.com", CoreHostNormalization.normalize("http://example.com")
  end

  test "normalize handles http URL with path" do
    assert_equal "example.com", CoreHostNormalization.normalize("http://example.com/some/path")
  end

  test "normalize handles https URL with path" do
    assert_equal "example.com", CoreHostNormalization.normalize("https://example.com/some/path")
  end

  test "normalize handles IP address" do
    assert_equal "127.0.0.1", CoreHostNormalization.normalize("127.0.0.1")
  end

  test "normalize handles IP address with scheme" do
    assert_equal "127.0.0.1", CoreHostNormalization.normalize("https://127.0.0.1")
  end

  test "normalize removes path component from plain host with slash" do
    assert_equal "example.com", CoreHostNormalization.normalize("example.com/path")
  end

  test "normalize handles host with non-standard port" do
    assert_equal "example.com", CoreHostNormalization.normalize("example.com:3000")
  end
end
