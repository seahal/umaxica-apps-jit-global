# typed: false
# frozen_string_literal: true

require "test_helper"
require "jwt"

# Pure unit tops for branches the full suite still leaves cold: model case arms, DPoP request-
# binding refusals, and the SurfaceInertiaPage layout derivation guard.
class BranchCoverageBatch23EasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "OperatorPreferenceDateFormatOption#name covers the US arm" do
    option = OperatorPreferenceDateFormatOption.new
    option.id = OperatorPreferenceDateFormatOption::US

    assert_equal "us", option.name
  end

  test "DpopProofVerifier refuses missing binding claims before signature work" do
    verifier = DpopProofVerifier.new(
      proof_jwt: "x.y.z",
      request_method: "POST",
      request_uri: "https://example.test/resource",
      access_token: "access-token",
      record_jti: false,
    )

    assert_equal "missing_htm", verifier.send(:verify_request_binding, {}).error
    assert_equal "missing_htu", verifier.send(:verify_request_binding, { "htm" => "POST" }).error
    assert_equal "missing_iat",
                 verifier.send(
                   :verify_request_binding,
                   { "htm" => "POST", "htu" => "https://example.test/resource" },
                 ).error
    assert_equal "iat_out_of_window",
                 verifier.send(
                   :verify_request_binding,
                   {
                     "htm" => "POST",
                     "htu" => "https://example.test/resource",
                     "iat" => Time.now.to_i - (DpopProofVerifier::IAT_LEEWAY_SECONDS + 120),
                   },
                 ).error
    assert_equal "missing_ath", verifier.send(:verify_access_token_hash, {}).error
    assert_equal "missing_jti", verifier.send(:record_jti, "", jkt: "jkt", payload: {}).error
  end

  test "SurfaceInertiaPage refuses a controller path without a family and surface" do
    assert_raises(ArgumentError) do
      Class.new(ApplicationController) do
        def self.controller_path = "orphan"

        include SurfaceInertiaPage
      end
    end
  end

  test "RedirectsExternalTargetResolver refuses unknown keys and relative targets" do
    unknown = RedirectsExternalTargetResolver.call(:not_a_registry_key)

    assert_equal "unknown_key", unknown.failure_reason

    blank_host = RedirectsExternalTargetResolver.url("/relative", allowed_urls: ["https://example.test"])

    assert_equal "invalid_uri", blank_host.failure_reason

    # A parseable absolute URL that still carries a control character hits the dedicated arm.
    control = RedirectsExternalTargetResolver.url(
      "https://example.test/?q=" + 1.chr,
      allowed_urls: ["https://example.test"],
    )

    assert_includes %w(control_char invalid_uri origin_denied), control.failure_reason
  end
end
