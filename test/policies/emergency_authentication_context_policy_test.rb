# typed: false
# frozen_string_literal: true

require "test_helper"

# Authorization for a Restricted Mode session is DB role AND session capability
# AND the ordinary policy rule.
#
# The capability layer is a pre-check on ApplicationPolicy rather than a
# condition inside each rule, so a sensitive action added tomorrow is covered
# without anyone remembering to guard it. That is what these tests protect: not
# the current rule list, but the fact that an unlisted rule is denied.
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

  test "an emergency session keeps read rules and loses every mutation" do
    policy = policy_with(emergency_claims)

    assert policy.apply(:index?)
    assert policy.apply(:show?)
    assert_not policy.apply(:create?)
    assert_not policy.apply(:update?)
    assert_not policy.apply(:destroy?)
  end

  # The point of a default-deny pre-check: `retire?` is not on any emergency
  # deny-list, and it is denied anyway.
  test "a sensitive rule nobody thought about is denied in an emergency session" do
    assert_not policy_with(emergency_claims).apply(:retire?)
  end

  test "a granting rule cannot override the capability layer" do
    policy = policy_with(emergency_claims)

    assert_predicate policy, :update?, "the rule itself still says yes"
    assert_not policy.apply(:update?), "but the applied decision, which is what authorize! uses, says no"
  end

  test "an unrecognised authentication context denies every rule" do
    policy = policy_with(normal_claims.merge(AuthenticationContextValue::CLAIM => "elevated"))

    %i(index? show? create? update? destroy?).each do |rule|
      assert_not policy.apply(rule), "a malformed context must fail closed, not fall through to normal"
    end
  end

  test "carrying org scopes does not restore what the emergency context withholds" do
    policy = policy_with(
      normal_claims.merge(AuthenticationContextValue::CLAIM => "emergency"),
    )

    assert_includes AuthorizationTokenClaims.scopes(policy.send(:current_token)), "write:org"
    assert_not policy.apply(:update?),
               "a scope claim must not be able to buy back a capability the context removed"
  end
end
