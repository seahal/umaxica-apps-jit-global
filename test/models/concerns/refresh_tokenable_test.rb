# typed: false
# frozen_string_literal: true

require "test_helper"

class RefreshTokenableTest < ActiveSupport::TestCase
  setup do
    ClientStatus.ensure_defaults!
    ClientTokenStatus.ensure_defaults!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::NOTHING)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)

    @user = Client.create!(
      public_id: "u_#{SecureRandom.hex(8)}",
      status_id: ClientStatus::ACTIVE,
      created_at: 1.day.ago,
      updated_at: 1.day.ago,
    )
  end

  test "create! seeds refresh metadata and device session" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_predicate token.refresh_token_family_id, :present?
    assert_equal 0, token.refresh_token_generation
    assert_predicate token.device_session_id, :present?
    assert_predicate token.device_session, :present?
  end

  test "refresh_token= stores a digest and clears it when blank" do
    token = ClientToken.new(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    token.refresh_token = "verifier-1"

    assert_predicate token.refresh_token_digest, :present?

    token.refresh_token = ""

    assert_nil token.refresh_token_digest
  end

  test "refresh token replay is terminal and revokes the whole family" do
    original = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      refresh_token: "first-verifier",
    )
    original_refresh_token = ClientToken.build_refresh_token(original.public_id, "first-verifier")

    first_rotation = AcmeRefreshTokenIssuer.call(refresh_token: original_refresh_token)
    replacement = first_rotation.fetch(:token)

    assert_predicate first_rotation, :success?
    assert_equal original.refresh_token_family_id, replacement.refresh_token_family_id

    replay = AcmeRefreshTokenIssuer.call(refresh_token: original_refresh_token)

    assert_not_predicate replay, :success?
    assert_equal :refresh_token_reuse_detected, replay.reason
    assert_predicate original.reload, :expired_refresh?
    assert_predicate replacement.reload, :expired_refresh?

    replacement_reuse = AcmeRefreshTokenIssuer.call(refresh_token: first_rotation.fetch(:refresh_token))

    assert_not_predicate replacement_reuse, :success?
    assert_equal :inactive_token, replacement_reuse.reason
  end

  test "rotation releases a unique dbsc session id on the previous token" do
    original = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      refresh_token: "first-verifier",
    )
    original.update!(dbsc_session_id: "session-1")
    original_refresh_token = ClientToken.build_refresh_token(original.public_id, "first-verifier")

    result = AcmeRefreshTokenIssuer.call(refresh_token: original_refresh_token)

    assert_predicate result, :success?
    assert_nil original.reload.dbsc_session_id
  end

  test "rotation preserves the authentication event time" do
    event_at = Time.utc(2026, 1, 2, 3, 4, 5)
    token = ClientToken.create!(user: clients(:one), authentication_event_at: event_at)

    replacement = token.rotate_refresh_token!

    assert_equal event_at, token.reload.authentication_event_at
    assert_equal event_at, ClientToken.find_by!(public_id: replacement.split(".", 2).first).authentication_event_at
  end

  test "expired_refresh? and active? reflect discarding time" do
    token = ClientToken.new(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.define_singleton_method(:discarded_at) { 1.day.from_now }

    assert_not_predicate token, :expired_refresh?
    assert_predicate token, :active?

    token.define_singleton_method(:discarded_at) { 1.minute.ago }

    assert_predicate token, :expired_refresh?
    assert_not_predicate token, :active?
  end
end
