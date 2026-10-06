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
      Struct.new(:has_usable_sign_in_capability_value, :has_usable_step_up_capability_value) do
      def has_usable_sign_in_capability? = has_usable_sign_in_capability_value

      def has_usable_step_up_capability? = has_usable_step_up_capability_value
    end

  test "public guards delegate to the inventory with exclusions" do
    actor = Object.new
    passkey = Object.new
    email = Object.new
    telephone = Object.new
    totp = Object.new
    inventory = Inventory.new(true, false)
    calls = []

    AuthenticationCredentialInventory.stub(
      :call,
      ->(current_actor, excluding: nil, reload: nil) do
        calls << [current_actor, excluding, reload]
        inventory
      end,
    ) do
      assert AuthMethodGuard.can_remove_passkey?(actor, passkey)
      assert AuthMethodGuard.can_remove_email?(actor, email)
      assert AuthMethodGuard.can_remove_telephone?(actor, telephone)
      assert AuthMethodGuard.can_remove_totp?(actor, totp)
    end

    assert_equal [
      [actor, nil, true], [actor, passkey, true],
      [actor, nil, true], [actor, email, true],
      [actor, nil, true], [actor, telephone, true],
      [actor, nil, true], [actor, totp, true],
    ], calls
  end
end
