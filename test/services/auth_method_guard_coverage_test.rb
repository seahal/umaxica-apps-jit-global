# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthMethodGuardCoverageTest < ActiveSupport::TestCase
  Scope =
    Struct.new(:count_value, :not_calls) do
      def initialize(...)
        super
        self.not_calls ||= []
      end

      def where(*_args)
        self
      end

      def not(**kwargs)
        not_calls << kwargs
        self.count_value = [count_value - 1, 0].max if count_value.to_i > 0
        self
      end

      def count
        count_value
      end
    end

  Inventory =
    Struct.new(
      :aal1_method_count, :retains_aal1_value, :retains_aal2_value, :retains_contactability_value,
      :retains_uv_step_up_value,
    ) do
      def retains_aal1? = retains_aal1_value

      def retains_aal2? = retains_aal2_value

      def retains_contactability? = retains_contactability_value

      def retains_uv_step_up? = retains_uv_step_up_value
    end

  test "public guards delegate to the inventory with exclusions" do
    actor = Object.new
    passkey = Object.new
    email = Object.new
    telephone = Object.new
    totp = Object.new
    inventory = Inventory.new(2, true, false, true, false)
    calls = []

    AuthenticationCredentialInventory.stub(
      :call,
      ->(current_actor, excluding: nil, reload: nil) do
        calls << [current_actor, excluding, reload]
        inventory
      end,
    ) do
      assert_equal 2, AuthMethodGuard.remaining_count(actor)
      assert_equal 2, AuthMethodGuard.remaining_count(actor, excluding: passkey)
      assert_not AuthMethodGuard.last_method?(actor)
      assert_not AuthMethodGuard.can_remove_passkey?(actor, passkey)
      assert_not AuthMethodGuard.can_remove_email?(actor, email)
      assert AuthMethodGuard.can_remove_telephone?(actor, telephone)
      assert_not AuthMethodGuard.can_remove_totp?(actor, totp)
    end

    assert_equal [
      [actor, nil, true],
      [actor, passkey, true],
      [actor, nil, true],
      [actor, passkey, true],
      [actor, email, true],
      [actor, telephone, true],
      [actor, totp, true],
    ], calls
  end
end
