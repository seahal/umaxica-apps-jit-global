# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAdmissionBindingTest < ActiveSupport::TestCase
  fixtures :client_tokens

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
