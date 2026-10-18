# typed: false
# frozen_string_literal: true

require "test_helper"

# External redirect targets are resolved from a registry keyed by name, never
# from a caller-supplied host. The origin comes from configuration if it is set
# and from the registry's own default otherwise, so an unset environment must not
# silently produce a blank origin -- that would resolve to a scheme-relative URL
# and hand the redirect to whatever host the browser was already on.
class RedirectsExternalTargetFallbackTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a key that is not in the registry is refused rather than guessed at" do
    %i(martian).each do |key|
      result = RedirectsExternalTargetResolver.call(key, path: "/")

      assert_not result.ok?
      assert_equal "unknown_key", result.failure_reason
    end

    assert_not RedirectsExternalTargetResolver.call("Not A Key", path: "/").ok?
    assert_not RedirectsExternalTargetResolver.call(42, path: "/").ok?
  end

  # A URL that cannot be parsed at all is refused as invalid rather than
  # propagating URI::InvalidURIError out of a redirect helper.
  test "an unparsable origin or URL is refused as an invalid URI" do
    unparsable = RedirectsExternalTargetResolver.url("http://[oops", allowed_urls: ["https://rp.app.localhost"])

    assert_not unparsable.ok?
    assert_equal "invalid_uri", unparsable.failure_reason

    assert_nil RedirectsExternalTargetResolver.normalized_origin("http://[oops")
    assert_nil RedirectsExternalTargetResolver.normalized_origin("not-a-url")
  end

  test "a non-default port is kept in the normalised origin and a default one is dropped" do
    assert_equal "https://example.test", RedirectsExternalTargetResolver.normalized_origin("https://example.test:443/x")
    assert_equal "https://example.test:8443",
                 RedirectsExternalTargetResolver.normalized_origin("https://EXAMPLE.test:8443/x")
    assert_equal "http://example.test", RedirectsExternalTargetResolver.normalized_origin("http://example.test:80/x")
  end
end
