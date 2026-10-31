# typed: false
# frozen_string_literal: true

require "test_helper"

# Restitution WU-A6 (AC-41): the authentication-context layer is operation-blind.
# An org emergency session answers to the ordinary policy rule exactly like a normal
# session, so a comparison over every declared policy operation must find no
# difference between the two contexts, and an unrecognised context must deny
# every rule instead of falling through to Normal.
#
# Inventory note: this guard enumerates the concrete policy classes under
# app/policies and their public rule predicates. A policy keeps ordinary deny
# semantics under both contexts; the sensitive-operation boundary is that
# operation's Step-Up gate, never the context layer.
class AuthenticationContextOperationInventoryTest < ActiveSupport::TestCase
  # Structural scopes are untouched by the capability layer in every context;
  # the capability-named ones are the only privileges a token claim carries.
  CONTEXTS_UNDER_COMPARISON = {
    normal: -> { AuthenticationContextValue.normal },
    standby: -> { AuthenticationContextValue.standby },
  }.freeze

  test "every declared policy operation decides identically for normal and standby sessions" do
    compared = 0

    policy_classes.each do |policy_class|
      declared_rules(policy_class).each do |rule|
        outcomes =
          CONTEXTS_UNDER_COMPARISON.transform_values(&:call)
            .transform_values { |context| context.permits_rule?(rule) }

        assert_equal outcomes.fetch(:normal), outcomes.fetch(:standby),
                     "#{policy_class}##{rule} must not differ by authentication context"
        assert outcomes.fetch(:normal), "#{policy_class}##{rule} must remain under the ordinary rule"

        compared += 1
      end
    end

    assert_operator compared, :>, 0, "the policy inventory must not be empty"
  end

  test "an unrecognised authentication context denies every declared operation" do
    policy_classes.each do |policy_class|
      declared_rules(policy_class).each do |rule|
        assert_not AuthenticationContextValue::UNKNOWN.permits_rule?(rule),
                   "#{policy_class}##{rule} must fail closed for an unrecognised context"
      end
    end
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

  private

  def policy_classes
    Rails.application.eager_load!
    @policy_classes ||= ApplicationPolicy.descendants.select { |klass| klass.is_a?(Class) }
      .reject { |klass| klass.name.start_with?("Test") }.sort_by(&:name)
  end

  def declared_rules(policy_class)
    policy_class.public_instance_methods.select do |method_name|
      method_name.to_s.end_with?("?") && method_name != :deny_capability_restricted_context
    end.sort
  end
end
