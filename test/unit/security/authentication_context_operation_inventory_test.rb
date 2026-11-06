# typed: false
# frozen_string_literal: true

require "test_helper"

# Restitution WU-A6 (AC-41): the authentication-context layer is operation-blind.
# Apply each zero-argument public policy predicate through Action Policy's real
# pre-check under normal and standby token claims, and require the same outcome.
# An unrecognised context must deny before any ordinary rule can allow it.
#
# Inventory note: this guard enumerates the concrete policy classes under
# app/policies and their public rule predicates. A policy keeps ordinary deny
# semantics under both contexts; the sensitive-operation boundary is that
# operation's Step-Up gate, never the context layer.
class AuthenticationContextOperationInventoryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # The authorization engine reads this trusted context from the installed token claims.
  CONTEXTS_UNDER_COMPARISON = {
    normal: -> { AuthenticationContextValue.normal },
    standby: -> { AuthenticationContextValue.standby },
  }.freeze

  test "every declared policy operation decides identically for normal and standby sessions" do
    compared = 0

    Actor.reset
    policy_classes.each do |policy_class|
      declared_rules(policy_class).each do |rule|
        outcomes =
          CONTEXTS_UNDER_COMPARISON.to_h do |name, context_factory|
            authentication_context = context_factory.call
            token_claims = {
              "scope" => "authenticated domain:operator read:org write:org",
              AuthenticationContextValue::CLAIM => authentication_context.key,
            }
            Actor.install_context!(
              authz: Actor::Authz.new(policy_user: nil, token_claims: token_claims, surface: "org"),
            )

            policy = policy_class.new(policy_record(policy_class), user: nil)
            [name, !!policy.apply(rule)]
          end

        assert_equal outcomes.fetch(:normal), outcomes.fetch(:standby),
                     "#{policy_class}##{rule} must not differ by authentication context"

        compared += 1
      end
    end

    assert_operator compared, :>, 0, "the policy inventory must not be empty"
  ensure
    Actor.reset
  end

  test "an unrecognised authentication context denies every declared operation" do
    Actor.reset
    token_claims = {
      "scope" => "authenticated domain:operator read:org write:org",
      AuthenticationContextValue::CLAIM => "elevated",
    }
    Actor.install_context!(
      authz: Actor::Authz.new(policy_user: nil, token_claims: token_claims, surface: "org"),
    )

    policy_classes.each do |policy_class|
      declared_rules(policy_class).each do |rule|
        policy = policy_class.new(policy_record(policy_class), user: nil)

        assert_not policy.apply(rule),
                   "#{policy_class}##{rule} must fail closed for an unrecognised context"
      end
    end
  ensure
    Actor.reset
  end

  test "the one session capability is step-up, and the named scope privileges stay closed" do
    assert_equal ["step_up"], AuthenticationContextValue::REGISTRY.fetch("normal").capabilities
    assert_empty AuthenticationContextValue::REGISTRY.fetch("standby").capabilities
    assert_equal %w(read:org write:org read:self write:self),
                 AuthenticationContextValue::CAPABILITY_NAMED_SCOPES
    # A standby session is never issued more than the same actor's normal claims.
    operator_scopes = %w(authenticated domain:operator read:org write:org)

    assert_equal AuthenticationContextValue.normal.constrain_scopes(operator_scopes),
                 AuthenticationContextValue.standby.constrain_scopes(operator_scopes)
  end

  test "an ordinary publishing write keeps the active-operator policy in normal and standby" do
    operator = Operator.new

    assert_predicate operator, :active?

    entry = Publishing::Docs::Org::Entry.new
    outcomes =
      {
        normal: AuthenticationContextValue::NORMAL_KEY,
        standby: AuthenticationContextValue::STANDBY_KEY,
        unknown: "elevated",
      }.to_h do |name, context|
        claims = {
          "scope" => "authenticated domain:operator read:org write:org",
          AuthenticationContextValue::CLAIM => context,
        }
        Actor.install_context!(
          authz: Actor::Authz.new(policy_user: operator, token_claims: claims, surface: "org"),
        )
        policy = PublishingEntryPolicy.new(entry, user: operator)
        [name, !!policy.apply(:create?)]
      end

    assert_equal({ normal: true, standby: true, unknown: false }, outcomes)
  ensure
    Actor.reset
  end

  private

  def policy_record(policy_class)
    return nil unless policy_class == Authentication::AccessPolicy

    AuthenticationBase::AccessPolicyContext.new(
      policy: :public_strict,
      options: {},
      controller_name: "PolicyInventoryTestController",
      action_name: "index",
      logged_in: true,
      current_resource_deactivated: false,
    )
  end

  def policy_classes
    Rails.application.eager_load!
    @policy_classes ||= ApplicationPolicy.descendants.select { |klass| klass.is_a?(Class) }
      .reject { |klass| klass.name.start_with?("Test") }.sort_by(&:name)
  end

  def declared_rules(policy_class)
    policy_class.ancestors
      .take_while { |ancestor| ancestor != ApplicationPolicy.superclass }
      .flat_map do |ancestor|
        ancestor.public_instance_methods(false).select do |method_name|
          method_name.to_s.end_with?("?") && ancestor.instance_method(method_name).arity.zero? &&
            method_name != :deny_capability_restricted_context
        end
      end.uniq.sort
  end
end
