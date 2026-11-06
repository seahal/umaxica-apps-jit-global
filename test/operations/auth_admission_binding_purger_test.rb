# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAdmissionBindingPurgerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "retired binding remains until its parent deadline and retention boundary in every realm" do
    %w(app org).each do |surface|
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
    %w(app org).each do |surface|
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
      assert_not continuity.class.exists?(continuity.id), "expired unadmitted continuity is purged after its binding"
      assert AuthAdmissionBindingPurger.purge_for_parent!(
        parent:, now: boundary + Rational(1, 1_000_000), retention_period: 1.second,
      )
    end
  end

  test "admitted Auth continuity is purged after its expiry and final binding reference in every realm" do
    %w(app org).each do |surface|
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      binding_model = BaseAuthAdmissionCoordinator.admission_binding_model(surface)
      binding = binding_model.find_by!(entry_ref: issuance.reference)
      session_model = binding_model.auth_admission_session_class
      continuity, = session_model.issue!
      continuity.admit!(
        admission_purpose: "authentication_handoff",
        authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      binding.attach_auth_session!(auth_session: continuity, confirmation_ref: SecureRandom.uuid)
      binding.retire!
      parent = issuance.transaction.reload
      purge_time = [parent.expires_at, binding.expires_at, continuity.expires_at].max + 2.seconds

      assert AuthAdmissionBindingPurger.purge_for_parent!(
        parent:, now: purge_time, retention_period: 1.second,
      )
      assert_not binding_model.exists?(binding.id)
      assert_not session_model.exists?(continuity.id)
    end
  end

  test "terminal Auth continuity is purged only after its status event reaches retention in every realm" do
    %w(app org).each do |surface|
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      binding_model = BaseAuthAdmissionCoordinator.admission_binding_model(surface)
      binding = binding_model.find_by!(entry_ref: issuance.reference)
      session_model = binding_model.auth_admission_session_class
      continuity, = session_model.issue!
      binding.attach_auth_session!(auth_session: continuity, confirmation_ref: SecureRandom.uuid)
      binding.retire!
      terminal_at = continuity.expires_at + 1.hour
      session_model.stub(:database_now, terminal_at) { continuity.revoke! }
      parent = issuance.transaction.reload
      purge_time = [parent.expires_at, binding.expires_at, continuity.expires_at].max + 2.seconds
      cutoff = purge_time - 1.second

      assert_operator cutoff, :<, continuity.revoked_at
      assert_not AuthAdmissionBindingPurger.purge_for_parent!(
        parent:, now: purge_time, retention_period: 1.second,
      )
      assert binding_model.exists?(binding.id)
      assert session_model.exists?(continuity.id)

      purge_time = continuity.revoked_at + 1.second

      assert AuthAdmissionBindingPurger.purge_for_parent!(
        parent:, now: purge_time, retention_period: 1.second,
      )
      assert_not binding_model.exists?(binding.id)
      assert_not session_model.exists?(continuity.id)
    end
  end

  test "completed and cancelled Auth continuity is purged after its status retention in every realm" do
    %w(app org).each do |surface|
      %i(completed cancelled).each do |terminal_state|
        issuance = OidcTestEntry.issue!(
          surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
        )
        binding_model = BaseAuthAdmissionCoordinator.admission_binding_model(surface)
        binding = binding_model.find_by!(entry_ref: issuance.reference)
        session_model = binding_model.auth_admission_session_class
        continuity, = session_model.issue!
        continuity.admit!(
          admission_purpose: "authentication_handoff",
          authorization_transaction_ref: issuance.transaction.transaction_id,
        )
        binding.attach_auth_session!(auth_session: continuity, confirmation_ref: SecureRandom.uuid)
        binding.retire!

        if terminal_state == :completed
          continuity.complete!

          assert_predicate continuity.reload, :completed?
        else
          continuity.cancel!

          assert_predicate continuity.reload, :cancelled?
        end

        parent = issuance.transaction.reload
        purge_time = [parent.expires_at, binding.expires_at, continuity.expires_at].max + 2.seconds

        assert AuthAdmissionBindingPurger.purge_for_parent!(
          parent:, now: purge_time, retention_period: 1.second,
        )
        assert_not binding_model.exists?(binding.id)
        assert_not session_model.exists?(continuity.id)
      end
    end
  end

  test "expired unadmitted continuity remains until its last binding passes retention in every realm" do
    %w(app org).each do |surface|
      issuances =
        2.times.map do
          OidcTestEntry.issue!(
            surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
          )
        end
      binding_model = BaseAuthAdmissionCoordinator.admission_binding_model(surface)
      session_model = binding_model.auth_admission_session_class
      bindings =
        issuances.map do |issuance|
          binding_model.find_by!(entry_ref: issuance.reference)
        end
      continuity, = session_model.issue!
      bindings.each do |binding|
        binding.attach_auth_session!(auth_session: continuity, confirmation_ref: SecureRandom.uuid)
        binding.retire!
      end
      purge_time = [*issuances.map { |issuance| issuance.transaction.reload.expires_at },
                    continuity.expires_at,].max + 2.seconds

      assert AuthAdmissionBindingPurger.purge_for_parent!(
        parent: issuances.first.transaction, now: purge_time, retention_period: 1.second,
      )
      assert_not binding_model.exists?(id: bindings.first.id)
      assert binding_model.exists?(id: bindings.last.id)
      assert session_model.exists?(id: continuity.id)

      assert AuthAdmissionBindingPurger.purge_for_parent!(
        parent: issuances.last.transaction, now: purge_time, retention_period: 1.second,
      )
      assert_not binding_model.exists?(id: bindings.last.id)
      assert_not session_model.exists?(id: continuity.id)
    end
  end
end
