# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAdmissionBindingTest < ActiveSupport::TestCase
  fixtures :client_tokens

  test "confirmation references require UUID version four at adjacent representable versions in every realm" do
    %w(app com org).each do |surface|
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      auth_session, = binding.class.auth_admission_session_class.issue!
      ["00000000-0000-3000-8000-000000000001", "00000000-0000-5000-8000-000000000001"].each do |reference|
        assert_raises(AuthAdmissionBinding::InvalidTransition, "#{surface}: UUID version adjacent to four") do
          binding.attach_auth_session!(auth_session:, confirmation_ref: reference)
        end
        assert_equal [nil, nil], [binding.reload.auth_ceremony_session_id, binding.confirmation_ref]
      end
      reference = "00000000-0000-4000-8000-000000000001"
      binding.attach_auth_session!(auth_session:, confirmation_ref: reference)

      assert_equal [auth_session.id, reference], [binding.reload.auth_ceremony_session_id, binding.confirmation_ref]
    end
  end

  test "every realm database rejects invalid parent and partial admission proof writes" do
    %w(app com org).each do |surface|
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      auth_session, = binding.class.auth_admission_session_class.issue!
      invalid_writes = [
        [{ sign_in_flow_id: nil }, "one_parent"],
        [{ step_up_ceremony_transaction_id: binding.sign_in_flow_id }, "one_parent"],
        [{ purpose: "step_up_handoff" }, "parent_purpose"],
        [{ confirmation_ref: SecureRandom.uuid }, "auth_proof_pair"],
        [{ auth_ceremony_session_id: auth_session.id }, "auth_proof_pair"],
        [{ base_confirmed_at: binding.class.database_now }, "confirmation_requires_auth"],
        [{ redeemed_at: binding.class.database_now }, "redemption_pair"],
        [{ admitted_auth_ceremony_session_id: auth_session.id }, "redemption_pair"],
      ]
      invalid_writes.each do |attributes, constraint|
        error =
          assert_raises(ActiveRecord::StatementInvalid, "#{surface}: #{constraint}") do
            binding.class.transaction(requires_new: true) do
              # Deliberately bypass model validation through public persistence to check actual DB invariants.
              binding.update_columns(attributes)
            end
          end

        assert_includes error.message, "admission_bindings_#{constraint}"
        assert_equal [nil, nil, nil, nil],
                     [binding.reload.auth_ceremony_session_id, binding.confirmation_ref,
                      binding.base_confirmed_at, binding.redeemed_at,]
      end

      %i(entry_ref purpose base_browser_digest expires_at).each do |fact|
        changed =
          case fact
          when :entry_ref then SecureRandom.uuid
          when :purpose then "local_sign_up"
          when :base_browser_digest then "b" * 64
          when :expires_at then binding.expires_at + 1.second
          end
        assert_raises(AuthAdmissionBinding::InvalidTransition, "#{surface}: immutable #{fact}") do
          binding.update!(fact => changed)
        end
        binding.reload
      end

      duplicate = binding.attributes.except("id").merge("entry_ref" => SecureRandom.uuid)
      assert_raises(ActiveRecord::RecordNotUnique, "#{surface}: one live binding per parent") do
        binding.class.transaction(requires_new: true) { binding.class.create!(duplicate) }
      end
      assert_equal issuance.transaction.id, binding.reload.sign_in_flow_id
    end
  end

  test "each realm binding expiry uses a strict deadline at the nearest database microsecond" do
    %w(app com org).each do |surface|
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      deadline = binding.expires_at
      microsecond = Rational(1, 1_000_000)

      assert binding.live?(now: deadline - microsecond), "#{surface}: immediately below expiry"
      assert_not binding.expired?(now: deadline - microsecond), surface
      assert_not binding.live?(now: deadline), surface
      assert binding.expired?(now: deadline), "#{surface}: exactly at expiry"
      assert_not binding.live?(now: deadline + microsecond), surface
      assert binding.expired?(now: deadline + microsecond), "#{surface}: immediately above expiry"
      assert_equal deadline, binding.reload.expires_at
      assert_nil binding.retired_at
      assert_nil binding.redeemed_at
    end
  end

  test "each realm database refuses redemption without a Base confirmation" do
    [
      ["app", ClientAuthAdmissionBinding, ClientAuthCeremonySession],
      ["com", VisitorAuthAdmissionBinding, VisitorAuthCeremonySession],
      ["org", OperatorAuthAdmissionBinding, OperatorAuthCeremonySession],
    ].each do |surface, binding_model, session_model|
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = binding_model.find_by!(entry_ref: issuance.reference)
      auth_session, = session_model.issue!
      binding.attach_auth_session!(auth_session: auth_session, confirmation_ref: SecureRandom.uuid)
      binding.assign_attributes(
        redeemed_at: binding_model.database_now, admitted_auth_ceremony_session_id: auth_session.id,
      )

      assert_not_predicate binding, :valid?, "model validation also requires Base confirmation"
      binding.reload
      assert_raises(ActiveRecord::StatementInvalid, surface) do
        binding_model.transaction(requires_new: true) do
          # This direct public persistence write deliberately bypasses model validation to exercise the CHECK.
          binding.update_columns(
            redeemed_at: binding_model.database_now,
            admitted_auth_ceremony_session_id: auth_session.id,
          )
        end
      end

      assert_nil binding.reload.redeemed_at
      assert_nil binding.admitted_auth_ceremony_session_id
      assert_nil binding.base_confirmed_at
    end
  end

  test "binding transitions reject caller-supplied decision clocks" do
    binding = create_binding(create_authorization_transaction)
    auth_session, = ClientAuthCeremonySession.issue!
    assert_raises(ArgumentError) do
      binding.attach_auth_session!(auth_session: auth_session, confirmation_ref: SecureRandom.uuid, now: 1.day.ago)
    end
    assert_raises(ArgumentError) do
      binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest, now: 1.day.ago)
    end
    assert_raises(ArgumentError) do
      binding.redeem!(auth_session: auth_session, admitted_auth_session: auth_session, now: 1.day.ago)
    end
    assert_raises(ArgumentError) { binding.retire!(now: 1.day.ago) }
    assert_not_predicate binding.reload, :attached?
    assert_not_predicate binding, :confirmed?
    assert_not_predicate binding, :redeemed?
    assert_not_predicate binding, :retired?
  end

  test "distinct pending parents may attach the same active Auth continuity in every realm" do
    [
      ["app", ClientAuthAdmissionBinding, ClientAuthCeremonySession],
      ["com", VisitorAuthAdmissionBinding, VisitorAuthCeremonySession],
      ["org", OperatorAuthAdmissionBinding, OperatorAuthCeremonySession],
    ].each do |surface, binding_model, session_model|
      browser_nonce = SecureRandom.urlsafe_base64(32)
      first = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: surface, intent: "sign_in", base_browser_nonce: browser_nonce, base_token: nil,
      )
      second = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: surface, intent: "sign_in", base_browser_nonce: browser_nonce, base_token: nil,
      )
      first_binding = binding_model.find_by!(entry_ref: first.reference)
      second_binding = binding_model.find_by!(entry_ref: second.reference)
      auth_session, = session_model.issue!
      first_binding.attach_auth_session!(auth_session: auth_session, confirmation_ref: SecureRandom.uuid)
      second_binding.attach_auth_session!(auth_session: auth_session, confirmation_ref: SecureRandom.uuid)

      assert_not_equal first.transaction.id, second.transaction.id
      assert_not_equal first_binding.entry_ref, second_binding.entry_ref
      assert_equal auth_session.id, first_binding.reload.auth_ceremony_session_id
      assert_equal auth_session.id, second_binding.reload.auth_ceremony_session_id
      assert_nil first_binding.base_confirmed_at
      assert_nil second_binding.base_confirmed_at
      assert_nil first_binding.redeemed_at
      assert_nil second_binding.redeemed_at
      assert_not_predicate auth_session.reload, :admitted?
    end
  end

  test "rejects zero or multiple admission parents and partial proof pairs" do
    attrs = binding_attributes

    assert_not ClientAuthAdmissionBinding.new(attrs).valid?

    multiple = ClientAuthAdmissionBinding.new(attrs.merge(sign_in_flow_id: 1, authorization_transaction_id: 1))

    assert_not multiple.valid?
    assert_includes multiple.errors[:base], "exactly one admission parent is required"

    partial = ClientAuthAdmissionBinding.new(attrs.merge(auth_ceremony_session_id: 1))

    assert_not partial.valid?
    assert_includes partial.errors[:base], "Auth session and confirmation reference must be supplied together"
  end

  test "attaches, confirms and redeems once without reopening terminal facts" do
    parent = create_authorization_transaction
    entry_ref = SecureRandom.uuid
    digest = AuthAdmissionBinding.browser_digest(
      surface: "app", entry_ref:, nonce: "base-browser-nonce",
    )
    binding = create_binding(parent, entry_ref:, base_token_id: client_tokens(:one).id, base_browser_digest: digest)
    auth_session, raw_sid = ClientAuthCeremonySession.issue!

    binding.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: client_tokens(:one), browser_digest: digest)

    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session:, admitted_auth_session: admitted)

    binding.reload

    assert_predicate binding, :redeemed?
    assert_predicate binding, :confirmed?
    assert_equal admitted.id, binding.admitted_auth_ceremony_session_id
    assert_raises(AuthAdmissionBinding::InvalidTransition) { binding.retire! }
    assert_nothing_raised do
      binding.redeem!(auth_session:, admitted_auth_session: admitted)
    end
  end

  test "rejects changes to immutable identity and proof facts" do
    binding = create_binding(create_authorization_transaction)

    assert_raises(AuthAdmissionBinding::InvalidTransition) do
      binding.update!(purpose: "invitation_handoff")
    end
    assert_raises(AuthAdmissionBinding::InvalidTransition) do
      binding.update!(base_browser_digest: "b" * 64)
    end
    assert_raises(AuthAdmissionBinding::InvalidTransition) do
      binding.update!(expires_at: 30.minutes.from_now)
    end
  end

  test "same parent has one live binding, and expiry is retired explicitly" do
    parent = create_authorization_transaction
    first = create_binding(parent)
    second = ClientAuthAdmissionBinding.new(binding_attributes.merge(authorization_transaction_id: parent.id))

    assert_raises(ActiveRecord::RecordNotUnique) { second.save!(validate: true) }

    expired = create_binding(
      create_authorization_transaction(login_challenge: "expired-#{SecureRandom.uuid}"),
      expires_at: 1.second.ago,
    )

    assert_not expired.live?
    expired.retire!

    assert_predicate expired.reload, :retired?
    assert_not expired.redeemed?
    assert_equal first.id, first.reload.id
  end

  private

  def binding_attributes
    {
      entry_ref: SecureRandom.uuid,
      purpose: "authentication_handoff",
      base_browser_digest: "a" * 64,
      expires_at: 10.minutes.from_now,
      created_at: Time.current,
      updated_at: Time.current,
    }
  end

  def create_binding(parent, **overrides)
    ClientAuthAdmissionBinding.create!(
      binding_attributes.merge(authorization_transaction_id: parent.id).merge(overrides),
    )
  end

  def create_authorization_transaction(login_challenge: SecureRandom.uuid)
    now = ClientOidcAuthorizationTransaction.database_now
    ClientOidcAuthorizationTransaction.create_transaction!(
      surface: "app", intent: "sign_in", client_id: "test-client",
      redirect_uri: "https://client.example.test/callback", response_type: "code",
      scope: "openid", state: SecureRandom.urlsafe_base64(16), nonce: SecureRandom.urlsafe_base64(16),
      code_challenge: "a" * 43, code_challenge_method: "S256", login_challenge: login_challenge,
      login_challenge_expires_at: now + 10.minutes, expires_at: now + 10.minutes, now: now,
    )
  end
end
