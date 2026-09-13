# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Tests for ApplicationPolicy JWT integration via Actor.authz.token_claims
class ApplicationPolicyJwtTest < ActiveSupport::TestCase
  setup do
    Actor.reset
  end

  teardown do
    Actor.reset
  end

  class TestRecord
    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  # JWT scopes from Actor.authz.token_claims
  def test_jwt_scopes_returns_empty_array_when_no_token
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_empty policy.send(:jwt_scopes)
  end

  def test_jwt_scopes_extracts_scopes_from_current_token
    set_current_claims(
      "scope" => "authenticated domain:client read:self",
    )
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_equal ["authenticated", "domain:client", "read:self"], policy.send(:jwt_scopes)
  end

  def test_jwt_scopes_returns_empty_when_scp_missing
    set_current_claims("sub" => 123)
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_empty policy.send(:jwt_scopes)
  end

  # has_scope? checks
  def test_has_scope_returns_true_when_scope_present
    set_current_claims("scope" => "authenticated read:self")
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:has_scope?, "authenticated")
    assert policy.send(:has_scope?, "read:self")
  end

  def test_has_scope_returns_false_when_scope_missing
    set_current_claims("scope" => "authenticated")
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_not policy.send(:has_scope?, "admin")
  end

  def test_has_scope_handles_symbol_arguments
    set_current_claims("scope" => "read:self")
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:has_scope?, :"read:self")
  end

  # Domain extraction from audience
  def test_extract_domain_from_audience_returns_nil_without_token
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_nil policy.send(:extract_domain_from_audience)
  end

  def test_extract_domain_from_audience_extracts_domain
    set_current_claims("aud" => ["app.api.example.com"])
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_equal "app", policy.send(:extract_domain_from_audience)
  end

  def test_extract_domain_from_audience_extracts_org_domain
    set_current_claims("aud" => ["org.example.com", "api.example.com"])
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_equal "org", policy.send(:extract_domain_from_audience)
  end

  # Domain check helpers
  def test_domain_app_returns_true_for_app_domain
    set_current_claims("aud" => ["app.example.com"])
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:domain_app?)
    assert_not policy.send(:domain_org?)
    assert_not policy.send(:domain_com?)
  end

  def test_domain_org_returns_true_for_org_domain
    set_current_claims("aud" => ["org.example.com"])
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:domain_org?)
    assert_not policy.send(:domain_app?)
  end

  def test_domain_helpers_return_false_without_token
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_not policy.send(:domain_app?)
    assert_not policy.send(:domain_org?)
    assert_not policy.send(:domain_com?)
  end

  # domain_permitted? checks
  def test_domain_permitted_returns_true_when_allowed
    set_current_claims("aud" => ["app.example.com"])
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:domain_permitted?, "app")
    assert policy.send(:domain_permitted?, "app", "org")
  end

  def test_domain_permitted_returns_false_when_not_allowed
    set_current_claims("aud" => ["app.example.com"])
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_not policy.send(:domain_permitted?, "org")
  end

  def test_domain_permitted_returns_true_when_no_domains_specified
    set_current_claims("aud" => ["app.example.com"])
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:domain_permitted?) # no restrictions
  end

  def test_domain_permitted_returns_true_when_domain_nil
    # If token has no audience or malformed, allow by default
    set_current_claims({})
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:domain_permitted?, "app")
  end

  # jwt_subject extraction
  def test_jwt_subject_returns_nil_without_token
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_nil policy.send(:jwt_subject)
  end

  def test_jwt_subject_extracts_subject
    set_current_claims("sub" => 42)
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_equal 42, policy.send(:jwt_subject)
  end

  # Integration example: combining JWT + DB check
  def test_combining_jwt_and_db_check_example
    user = clients(:one) # from fixtures
    set_current_claims(
      "sub" => user.id,
      "scope" => "authenticated read:self domain:client",
      "aud" => ["app.api.example.com"],
    )

    # Example: Policy that checks JWT scope AND DB ownership
    # Use a record that has user_id attribute for owner? check
    Struct.new(:client_id).new(user.id)
    policy = ApplicationPolicy.new(user: user)

    # Has correct scope?
    assert policy.send(:has_scope?, "read:self")

    # Correct domain?
    assert policy.send(:domain_app?)

    # Is owner? (DB check - record.user_id == actor.id)
    assert policy.send(:owner?)
  end

  private

  def set_current_claims(claims)
    Actor.install_context!(authz: Actor::Authz.new(policy_user: nil, token_claims: claims, surface: nil))
  end
end
