# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationPolicyActorContextTest < ActiveSupport::TestCase
  class ActorFirstPolicy < ApplicationPolicy
    def show?
      actor.is_a?(Actor::Context) && user.equal?(record)
    end
  end

  setup do
    Actor.reset
  end

  teardown do
    Actor.reset
  end

  test "application policy receives actor context as primary context" do
    client = clients(:one)
    context = Actor.context.with(subject: client, actor_type: :client)
    policy = ActorFirstPolicy.new(client, actor: context)

    assert_same context, policy.actor
    assert_same client, policy.user
    assert policy.apply(:show?)
  end

  test "legacy user context remains compatible" do
    client = clients(:one)
    policy = ActorFirstPolicy.new(client, user: client)

    assert_nil policy.actor
    assert_same client, policy.user
    assert_not policy.apply(:show?)
  end
end
