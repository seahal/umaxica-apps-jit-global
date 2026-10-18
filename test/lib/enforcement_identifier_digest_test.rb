# typed: false
# frozen_string_literal: true

require "test_helper"

class EnforcementIdentifierDigestTest < ActiveSupport::TestCase
  # `Rails.application.envs` is one process-wide snapshot of the whole
  # environment (ActiveSupport::EnvConfiguration#reload does `@envs = ENV.to_h`)
  # and is the first backend `Rails.app.creds` reads. `key_for` resolves through
  # creds before ENV, so this test has to reload the snapshot to make its own
  # ENV writes and deletions visible -- but a reload also picks up every other
  # variable set since boot. config/initializers/jwt.rb installs local JWT
  # signing material into ENV after the snapshot is first taken, so an
  # unrestored reload publishes those keys through `Rails.app.creds` for the
  # remainder of the process. Later tests that delete the same keys from ENV
  # then still see them via the creds fallback in JitSecurityJwtKeySource#value.
  # Put the original snapshot back so the leak stops at this test's boundary.
  setup do
    @previous_env_snapshot = Rails.application.envs.instance_variable_get(:@envs)
    @previous_app_key = ENV.fetch("ENFORCEMENT_APP_IDENTIFIER_HMAC_KEY", nil)
    @previous_com_key = ENV.fetch("ENFORCEMENT_COM_IDENTIFIER_HMAC_KEY", nil)
    ENV["ENFORCEMENT_APP_IDENTIFIER_HMAC_KEY"] = "test-app-enforcement-key"
    ENV["ENFORCEMENT_COM_IDENTIFIER_HMAC_KEY"] = "test-com-enforcement-key"
    Rails.application.envs.reload
  end

  teardown do
    ENV["ENFORCEMENT_APP_IDENTIFIER_HMAC_KEY"] = @previous_app_key
    ENV["ENFORCEMENT_COM_IDENTIFIER_HMAC_KEY"] = @previous_com_key
    # A failure before setup (fixture loading) leaves no snapshot; writing nil back would break
    # every later credential read in this worker.
    Rails.application.envs.instance_variable_set(:@envs, @previous_env_snapshot) if @previous_env_snapshot
  end

  test "for_email normalizes, digests, and stamps current versions" do
    result = EnforcementIdentifierDigest.for_email(realm: "app", value: " Person@Example.com ")

    assert_equal "email", result[:identifier_kind]
    assert_equal "person@example.com", result[:display_value]
    assert_equal EnforcementIdentifierDigest::CURRENT_KEY_VERSION, result[:key_version]
    assert_equal EnforcementIdentifierDigest::CURRENT_DIGEST_VERSION, result[:digest_version]
    assert_equal EnforcementIdentifierDigest::CURRENT_NORMALIZATION_VERSION, result[:normalization_version]
    assert_predicate result[:lookup_digest], :present?
  end

  test "for_email returns nil for a blank or invalid address" do
    assert_nil EnforcementIdentifierDigest.for_email(realm: "app", value: "")
    assert_nil EnforcementIdentifierDigest.for_email(realm: "app", value: "not-an-email")
  end

  test "the same normalized email produces the same digest within a realm" do
    first = EnforcementIdentifierDigest.for_email(realm: "app", value: "person@example.com")
    second = EnforcementIdentifierDigest.for_email(realm: "app", value: "PERSON@EXAMPLE.COM")

    assert_equal first[:lookup_digest], second[:lookup_digest]
  end

  test "the same identifier produces different digests across realms" do
    app_digest = EnforcementIdentifierDigest.for_email(realm: "app", value: "person@example.com")
    com_digest = EnforcementIdentifierDigest.for_email(realm: "com", value: "person@example.com")

    assert_not_equal app_digest[:lookup_digest], com_digest[:lookup_digest]
  end

  test "for_google_subject and for_apple_subject key on issuer plus subject, not email" do
    google = EnforcementIdentifierDigest.for_google_subject(
      realm: "app", issuer: "https://accounts.google.com",
      subject: "123",
    )
    apple = EnforcementIdentifierDigest.for_apple_subject(
      realm: "app", issuer: "https://appleid.apple.com",
      subject: "123",
    )

    assert_equal "google_subject", google[:identifier_kind]
    assert_equal "apple_subject", apple[:identifier_kind]
    assert_not_equal google[:lookup_digest], apple[:lookup_digest]
  end

  test "key_for raises for an unsupported realm" do
    assert_raises(ArgumentError) { EnforcementIdentifierDigest.key_for("unknown") }
  end

  test "key_for raises KeyError when the realm's secret credential is not provisioned" do
    ENV.delete("ENFORCEMENT_APP_IDENTIFIER_HMAC_KEY")
    Rails.application.envs.reload

    assert_raises(KeyError) { EnforcementIdentifierDigest.key_for("app") }
  end
end
