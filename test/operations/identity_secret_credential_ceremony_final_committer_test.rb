# frozen_string_literal: true

require "test_helper"

class IdentitySecretCredentialCeremonyFinalCommitterTest < ActiveSupport::TestCase
  test "app cannot enroll a Secret through the retired shared credential ceremony" do
    assert_no_difference("ClientSecretCredential.count") do
      error =
        assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
          IdentitySecretCredentialCeremonyFinalCommitter.call!(
            result_token: "not-an-app-issuance", actor: clients(:one),
            session_ref: client_tokens(:one).public_id, surface: "app",
          )
        end

      assert_equal "surface is invalid", error.message
    end
  end

  test "missing empty and unknown surface cannot enter another surface ceremony" do
    [nil, "", "net", "APP"].each do |surface|
      error =
        assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
          IdentitySecretCredentialCeremonyFinalCommitter.call!(
            result_token: "untrusted-result", actor: clients(:one),
            session_ref: client_tokens(:one).public_id, surface: surface,
          )
        end

      assert_equal "surface is invalid", error.message
    end
  end

  test "com and org require a verified ceremony result before persisting a credential" do
    [
      ["com", visitors(:reserved_visitor), "synthetic-com-session", VisitorSecretCredential],
      ["org", operators(:one), operator_tokens(:one).public_id, OperatorSecretCredential],
    ].each do |surface, actor, session_ref, credential_class|
      before = credential_class.count

      assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "untrusted-result", actor: actor, session_ref: session_ref, surface: surface,
        )
      end
      assert_equal before, credential_class.count
    end
  end
end
