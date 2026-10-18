# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationSessionRevokerTest < ActiveSupport::TestCase
  class FakeRelation
    def initialize(tokens)
      @tokens = tokens
    end

    def find_each
      @tokens.each { |token| yield token }
    end
  end

  class FakeToken
    attr_reader :revoke_calls

    def initialize
      @revoke_calls = 0
    end

    def revoke!
      @revoke_calls += 1
    end
  end

  test "tokens_for returns the matching token relation for each resource type" do
    user = Client.new(id: 1)
    staff = Operator.new(id: 2)
    visitor = Visitor.new(id: 3)

    assert_equal ClientToken.where(user_id: 1).to_sql, AuthenticationSessionRevoker.tokens_for(user).to_sql
    assert_equal OperatorToken.where(staff_id: 2).to_sql, AuthenticationSessionRevoker.tokens_for(staff).to_sql
    assert_equal VisitorToken.where(visitor_id: 3).to_sql, AuthenticationSessionRevoker.tokens_for(visitor).to_sql
  end

  test "tokens_for rejects unsupported resource types" do
    error = assert_raises(ArgumentError) { AuthenticationSessionRevoker.tokens_for(Object.new) }

    assert_match(/Unsupported resource type/, error.message)
  end

  test "revoke_all_for revokes each token from the relation" do
    tokens = [FakeToken.new, FakeToken.new]
    relation = FakeRelation.new(tokens)

    AuthenticationSessionRevoker.stub(:tokens_for, relation) do
      AuthenticationSessionRevoker.revoke_all_for(Client.new(id: 1))
    end

    assert_equal [1, 1], tokens.map(&:revoke_calls)
  end

  test "tokens_for_method returns sessions matching the method and sessions with no recorded method" do
    client = Client.create!(status_id: ClientStatus::ACTIVE)
    matching = ClientToken.create!(user_id: client.id, established_authentication_method: "passkey")
    unattributed = ClientToken.create!(user_id: client.id, established_authentication_method: nil)
    other_method = ClientToken.create!(user_id: client.id, established_authentication_method: "email")

    result_ids = AuthenticationSessionRevoker.tokens_for_method(client, "passkey").pluck(:id)

    assert_includes result_ids, matching.id
    assert_includes result_ids, unattributed.id
    assert_not_includes result_ids, other_method.id
  end

  test "tokens_for_method additionally includes TOTP step-up sessions only when the method is totp" do
    client = Client.create!(status_id: ClientStatus::ACTIVE)
    totp_matching = ClientToken.create!(user_id: client.id, established_authentication_method: "totp")
    passkey_with_totp_step_up = ClientToken.create!(
      user_id: client.id,
      established_authentication_method: "passkey",
      last_step_up_method: "totp",
      last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
    )
    passkey_without_step_up = ClientToken.create!(user_id: client.id, established_authentication_method: "passkey")

    totp_result_ids = AuthenticationSessionRevoker.tokens_for_method(client, "totp").pluck(:id)
    passkey_result_ids = AuthenticationSessionRevoker.tokens_for_method(client, "passkey").pluck(:id)

    assert_includes totp_result_ids, totp_matching.id
    assert_includes totp_result_ids, passkey_with_totp_step_up.id
    assert_includes passkey_result_ids, passkey_with_totp_step_up.id
    assert_not_includes passkey_result_ids, totp_matching.id
    assert_not_includes totp_result_ids, passkey_without_step_up.id
  end
end
