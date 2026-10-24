# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAdmissionBindingPurgerTest < ActiveSupport::TestCase
  test "retired binding remains until its parent deadline and retention boundary in every realm" do
    %w(app com org).each do |surface|
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      binding.retire!
      parent = issuance.transaction.reload
      early = binding.expires_at + 1.second
      boundary = parent.expires_at + 1.second

      assert_not AuthAdmissionBindingPurger.purge_for_parent!(parent:, now: early, retention_period: 1.second)
      assert binding.class.exists?(binding.id), "a live parent retains its original nonce correlation"
      assert_not AuthAdmissionBindingPurger.purge_for_parent!(
        parent:, now: boundary - Rational(1, 1_000_000), retention_period: 1.second,
      )
      assert binding.class.exists?(binding.id)
      assert AuthAdmissionBindingPurger.purge_for_parent!(parent:, now: boundary, retention_period: 1.second)
      assert_not binding.class.exists?(binding.id)
      assert parent.class.exists?(parent.id), "binding cleanup precedes its restrictive parent deletion"
      assert AuthAdmissionBindingPurger.purge_for_parent!(
        parent:, now: boundary + Rational(1, 1_000_000), retention_period: 1.second,
      )
    end
  end

  test "expired parent retains its binding until attached Auth continuity reaches retention in every realm" do
    %w(app com org).each do |surface|
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      continuity, = binding.class.auth_admission_session_class.issue!
      binding.attach_auth_session!(auth_session: continuity, confirmation_ref: SecureRandom.uuid)
      binding.retire!
      parent = issuance.transaction.reload
      boundary = [parent.expires_at, continuity.expires_at].max + 1.second

      assert_not AuthAdmissionBindingPurger.purge_for_parent!(
        parent:, now: boundary - Rational(1, 1_000_000), retention_period: 1.second,
      )
      assert binding.class.exists?(binding.id)
      assert AuthAdmissionBindingPurger.purge_for_parent!(parent:, now: boundary, retention_period: 1.second)
      assert_not binding.class.exists?(binding.id)
      assert continuity.class.exists?(continuity.id), "binding cleanup does not erase the referenced continuity"
      assert AuthAdmissionBindingPurger.purge_for_parent!(
        parent:, now: boundary + Rational(1, 1_000_000), retention_period: 1.second,
      )
    end
  end
end
