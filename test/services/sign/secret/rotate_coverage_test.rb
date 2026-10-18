# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignSecretRotateCoverageTest < ActiveSupport::TestCase
  test "call forwards arguments to issue and revoke and returns the rotated secret" do
    credential_collection =
      Class.new do
        def self.name = "CredentialCollection"
      end
    secret_credential_class =
      Class.new do
        def self.name = "SecretCredentialClass"
      end
    secret_credential = Object.new
    issued_result = SignSecretIssue::Result.new(
      secret_credential: :rotated_secret,
      raw_secret_credential: "raw-secret",
    )
    captured_issue_kwargs = nil
    captured_revoke_kwargs = nil

    SignSecretIssue.stub(
      :call, ->(**kwargs) {
               captured_issue_kwargs = kwargs
               issued_result
             },
    ) do
      SignSecretRevoke.stub(
        :call, ->(**kwargs) {
                 captured_revoke_kwargs = kwargs
                 true
               },
      ) do
        result =
          SignSecretRotate.call(
            credential_collection: credential_collection,
            secret_credential_class: secret_credential_class,
            secret_credential: secret_credential,
            name: "Login Secret",
            secret_kind: "login",
            usage_policy: "single_use",
            legacy_attributes: { "legacy" => true },
            delivery_method: "email",
            scope: "settings",
            max_uses: 3,
            max_failures: 2,
            not_before_at: 5.minutes.from_now,
            issued_at: Time.zone.local(2026, 1, 2, 3, 4, 5),
            issued_by_type: "Visitor",
            issued_by_id: 123,
            issued_by_ref: "visitor-123",
          )

        assert_equal :rotated_secret, result.secret_credential
        assert_equal "raw-secret", result.raw_secret_credential
      end
    end

    assert_equal credential_collection, captured_issue_kwargs[:credential_collection]
    assert_equal secret_credential_class, captured_issue_kwargs[:secret_credential_class]
    assert_equal "Login Secret", captured_issue_kwargs[:name]
    assert_equal "login", captured_issue_kwargs[:secret_kind]
    assert_equal "single_use", captured_issue_kwargs[:usage_policy]
    assert_equal({ "legacy" => true }, captured_issue_kwargs[:legacy_attributes])
    assert_equal "email", captured_issue_kwargs[:delivery_method]
    assert_equal "settings", captured_issue_kwargs[:scope]
    assert_equal 3, captured_issue_kwargs[:max_uses]
    assert_equal 2, captured_issue_kwargs[:max_failures]
    assert_equal Time.zone.local(2026, 1, 2, 3, 4, 5), captured_issue_kwargs[:issued_at]
    assert_equal "Visitor", captured_issue_kwargs[:issued_by_type]
    assert_equal 123, captured_issue_kwargs[:issued_by_id]
    assert_equal "visitor-123", captured_issue_kwargs[:issued_by_ref]

    assert_equal secret_credential, captured_revoke_kwargs[:secret_credential]
    assert_equal Time.zone.local(2026, 1, 2, 3, 4, 5), captured_revoke_kwargs[:now]
  end
end
