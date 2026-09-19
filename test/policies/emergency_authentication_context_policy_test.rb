# typed: false
# frozen_string_literal: true

require "test_helper"

# An Emergency session is authenticated and answers to the ordinary policy rule;
# what it cannot do is Step-Up, which is enforced by the Step-Up gates rather
# than here. The capability pre-check on ApplicationPolicy must therefore never
# widen a rule for an Emergency session, and must still fail closed for an
# authentication context it does not recognise.
class EmergencyAuthenticationContextPolicyTest < ActiveSupport::TestCase
  class PermissivePolicy < ApplicationPolicy
    def index? = true

    def show? = true

    def create? = true

    def update? = true

    def destroy? = true

    # Stands in for a sensitive action added after Emergency Access shipped,
    # whose author never heard of it.
    def retire? = true
  end

  Record = Struct.new(:id)

  setup do
    Actor.reset
  end

  teardown do
    Actor.reset
  end

  def policy_with(claims)
    Actor.install_context!(authz: Actor::Authz.new(policy_user: nil, token_claims: claims, surface: nil))
    PermissivePolicy.new(Record.new(1), user: Record.new(1))
  end

  def normal_claims = { "scope" => "authenticated domain:operator read:org write:org" }

  def emergency_claims
    normal_claims.merge(
      "scope" => "authenticated domain:operator read:org",
      AuthenticationContextValue::CLAIM => "emergency",
    )
  end

  test "a normal session is not narrowed by the capability layer" do
    policy = policy_with(normal_claims)

    %i(index? show? create? update? destroy? retire?).each do |rule|
      assert policy.apply(rule), "#{rule} must remain available to a normal session"
    end
  end

  test "a session minted before the claim existed is treated as normal" do
    policy = policy_with(normal_claims)

    assert policy.apply(:update?)
  end

  test "an emergency session follows the ordinary policy rules" do
    policy = policy_with(emergency_claims)

    %i(index? show? create? update? destroy? retire?).each do |rule|
      assert policy.apply(rule), "#{rule} must follow the ordinary policy rule in an emergency session"
    end
  end

  test "an emergency session never widens a rule that denies" do
    Actor.install_context!(authz: Actor::Authz.new(policy_user: nil, token_claims: emergency_claims, surface: nil))
    policy = ApplicationPolicy.new(Record.new(1), user: Record.new(1))

    %i(index? show? create? update? destroy?).each do |rule|
      assert_not policy.apply(rule), "#{rule} is denied by ApplicationPolicy and must stay denied"
    end
  end

  test "an unrecognised authentication context denies every rule" do
    policy = policy_with(normal_claims.merge(AuthenticationContextValue::CLAIM => "elevated"))

    %i(index? show? create? update? destroy?).each do |rule|
      assert_not policy.apply(rule), "a malformed context must fail closed, not fall through to normal"
    end
  end
end
