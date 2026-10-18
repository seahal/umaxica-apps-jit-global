# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationCredentialInventoryOwnerTest < ActiveSupport::TestCase
  class CredentialOwner
    include AuthenticationCredentialInventoryOwner
  end

  setup do
    @owner = CredentialOwner.new
    @excluding = Object.new
    @inventory =
      AuthenticationCredentialInventory::Result.new(
        actor: @owner,
        excluding: @excluding,
        sign_in_methods: [:email_otp],
        step_up_methods: [:email_otp, :passkey],
        uv_step_up_methods: [:email_otp, :passkey],
        contact_identifiers: [:email],
        phishing_resistant_methods: [:passkey],
      )
  end

  test "authentication inventory delegates to CredentialInventory with options" do
    calls = []
    replacement =
      lambda do |actor, excluding: nil, reload: false|
        calls << { actor: actor, excluding: excluding, reload: reload }
        @inventory
      end

    AuthenticationCredentialInventory.stub(:call, replacement) do
      assert_same @inventory, @owner.authentication_credential_inventory(excluding: @excluding, reload: true)
      assert_equal [{ actor: @owner, excluding: @excluding, reload: true }], calls
    end
  end

  test "credential inventory is the single inventory entry point" do
    with_inventory do
      assert_same @inventory, @owner.authentication_credential_inventory(excluding: @excluding)
    end
  end

  test "sign-in capabilities and login methods share inventory result" do
    with_inventory do
      assert_equal [:email_otp], @owner.sign_in_methods(excluding: @excluding)
      assert @owner.has_usable_sign_in_capability?(excluding: @excluding)
      assert_equal [:email_otp], @owner.usable_sign_in_capabilities(excluding: @excluding)
    end
  end

  test "step-up capabilities are independent from sign-in capabilities" do
    with_inventory do
      assert_equal [:email_otp, :passkey], @owner.step_up_methods(excluding: @excluding)
      assert_equal [:email_otp, :passkey], @owner.usable_step_up_capabilities(excluding: @excluding)
      assert @owner.has_usable_step_up_capability?(excluding: @excluding)
    end
  end

  test "contactability exposes inventory result" do
    with_inventory do
      assert_equal [:email], @owner.contact_identifiers(excluding: @excluding)
      assert_equal 1, @owner.contact_identifier_count(excluding: @excluding)
      assert @owner.has_contact_identifier?(excluding: @excluding)
    end
  end

  private

  def with_inventory
    AuthenticationCredentialInventory.stub(:call, @inventory) do
      yield
    end
  end
end
