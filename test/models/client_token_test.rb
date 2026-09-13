# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_tokens
# Database name: app_ticket
#
#  id                                 :bigint           not null, primary key
#  dbsc_challenge                     :text
#  dbsc_challenge_issued_at           :datetime
#  dbsc_public_key                    :jsonb
#  discarded_at                       :datetime         default(Infinity), not null
#  dpop_jkt                           :string
#  last_step_up_aal                   :string
#  last_step_up_at                    :datetime
#  last_step_up_audience              :string
#  last_step_up_method                :string
#  last_step_up_purpose               :string
#  last_step_up_scope                 :string
#  last_used_at                       :datetime
#  oidc_jti                           :uuid
#  oidc_scope                         :string
#  oidc_sid                           :uuid
#  purged_at                          :datetime         default(Infinity), not null
#  refresh_token_digest               :binary
#  refresh_token_generation           :integer          default(0), not null
#  rotated_at                         :datetime
#  selected_at                        :datetime
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  dbsc_session_id                    :string
#  device_session_id                  :bigint
#  last_step_up_session_public_id     :string
#  oidc_client_id                     :string(64)
#  oidc_connection_id                 :bigint
#  public_id                          :string(21)       default(""), not null
#  refresh_token_family_id            :string
#  selected_account_public_id         :string
#  selected_avatar_public_id          :string
#  selected_collective_public_id      :string
#  selected_collective_unit_public_id :string
#  user_id                            :bigint           not null
#  user_token_binding_method_id       :bigint           default(0), not null
#  user_token_dbsc_status_id          :bigint           default(0), not null
#  user_token_kind_id                 :bigint           default(11), not null
#  user_token_status_id               :bigint           default(1), not null
#
# Indexes
#
#  index_client_tokens_on_created_at                     (created_at)
#  index_client_tokens_on_dbsc_session_id                (dbsc_session_id) UNIQUE
#  index_client_tokens_on_device_session_id              (device_session_id)
#  index_client_tokens_on_discarded_at                   (discarded_at)
#  index_client_tokens_on_oidc_connection_id             (oidc_connection_id)
#  index_client_tokens_on_oidc_jti                       (oidc_jti)
#  index_client_tokens_on_oidc_sid                       (oidc_sid)
#  index_client_tokens_on_public_id                      (public_id) UNIQUE
#  index_client_tokens_on_purged_at                      (purged_at)
#  index_client_tokens_on_refresh_token_digest           (refresh_token_digest) UNIQUE
#  index_client_tokens_on_refresh_token_family_id        (refresh_token_family_id)
#  index_client_tokens_on_rotated_at                     (rotated_at)
#  index_client_tokens_on_selected_account_public_id     (selected_account_public_id)
#  index_client_tokens_on_selected_avatar_public_id      (selected_avatar_public_id)
#  index_client_tokens_on_selected_collective_public_id  (selected_collective_public_id)
#  index_client_tokens_on_user_id_and_last_step_up_at    (user_id,last_step_up_at)
#  index_client_tokens_on_user_id_and_oidc_client_id     (user_id,oidc_client_id)
#  index_client_tokens_on_user_token_binding_method_id   (user_token_binding_method_id)
#  index_client_tokens_on_user_token_dbsc_status_id      (user_token_dbsc_status_id)
#  index_client_tokens_on_user_token_kind_id             (user_token_kind_id)
#  index_client_tokens_on_user_token_status_id           (user_token_status_id)
#
# Foreign Keys
#
#  fk_rails_...                                    (user_token_kind_id => client_token_kinds.id) ON DELETE => restrict
#  fk_rails_...                                    (user_token_status_id => client_token_statuses.id) ON DELETE => restrict
#  fk_user_tokens_on_user_token_binding_method_id  (user_token_binding_method_id => client_token_binding_methods.id)
#  fk_user_tokens_on_user_token_dbsc_status_id     (user_token_dbsc_status_id => client_token_dbsc_statuses.id)
#
require "test_helper"

class ClientTokenTest < ActiveSupport::TestCase
  def setup
    @user = Client.create!(public_id: "u_#{SecureRandom.hex(8)}", status_id: ClientStatus::NOTHING)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "inherits from AppTicketRecord" do
    assert_operator ClientToken, :<, AppTicketRecord
    assert_operator ClientToken, :<, ApplicationRecord
    assert_not_operator ClientToken, :<, OrgTicketRecord
  end

  test "signed ref lookup uses mark connection owner" do
    assert_equal AppTicketRecord, ClientToken.send(:connection_owner)
  end

  test "signed ref lookup role defaults to reading" do
    assert_equal :reading, ClientToken.signed_ref_lookup_role
  end

  test "belongs to user" do
    association = ClientToken.reflect_on_association(:user)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
  end

  test "can be created with user" do
    assert_not_nil @token
    assert_equal @user.id, @token.user_id
  end

  test "assigns numeric id automatically" do
    assert_not_nil @token.id
    assert_kind_of Integer, @token.id
  end

  test "has created_at timestamp" do
    assert_not_nil @token.created_at
    assert_kind_of Time, @token.created_at
  end

  test "has updated_at timestamp" do
    assert_not_nil @token.updated_at
    assert_kind_of Time, @token.updated_at
  end

  test "user association loads user correctly" do
    assert_equal @user, @token.user
    assert_equal @user.id, @token.user.id
  end

  test "can load one fixture" do
    token_one = ClientToken.find_by!(public_id: "651")

    assert_not_nil token_one
    assert_not_nil token_one.user_id
  end

  test "can load two fixture" do
    token_two = ClientToken.find_by!(public_id: "615")

    assert_not_nil token_two
    assert_not_nil token_two.user_id
  end

  test "timestamp is set on creation" do
    user = Client.create!
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_not_nil token.created_at
    assert_not_nil token.updated_at
    assert_operator token.created_at, :<=, token.updated_at
  end

  test "timestamp updates on save" do
    original_updated_at = @token.updated_at
    travel 1.second do
      @token.update!(updated_at: Time.current)
    end

    assert_operator @token.updated_at, :>, original_updated_at
  end

  test "enforces maximum concurrent sessions per user" do
    user = Client.create!
    token_status = ClientTokenStatus.find(ClientTokenStatus::ACTIVE)
    token_kind = ClientTokenKind.find(ClientTokenKind::BROWSER_WEB)
    binding_method = ClientTokenBindingMethod.find(ClientTokenBindingMethod::NOTHING)
    dbsc_status = ClientTokenDbscStatus.find(ClientTokenDbscStatus::NOTHING)

    ClientToken::MAX_TOTAL_SESSIONS_PER_USER.times do
      ClientToken.create!(
        user: user,
        user_token_status: token_status,
        user_token_kind: token_kind,
        user_token_binding_method: binding_method,
        user_token_dbsc_status: dbsc_status,
      )
    end

    extra_token = ClientToken.new(
      user: user,
      user_token_status: token_status,
      user_token_kind: token_kind,
      user_token_binding_method: binding_method,
      user_token_dbsc_status: dbsc_status,
    )

    assert_not extra_token.valid?
    assert_includes extra_token.errors[:base],
                    "exceeds maximum concurrent sessions per user (#{ClientToken::MAX_TOTAL_SESSIONS_PER_USER})"
  end

  test "enforces maximum concurrent sessions per user ignores expired revoked discarded and rotated rows" do
    user = Client.create!
    token_kind = ClientTokenKind.find(ClientTokenKind::BROWSER_WEB)
    active_status = ClientTokenStatus.find(ClientTokenStatus::ACTIVE)
    expired_status = ClientTokenStatus.find(ClientTokenStatus::EXPIRED)
    revoked_status = ClientTokenStatus.find(ClientTokenStatus::REVOKED)
    binding_method = ClientTokenBindingMethod.find(ClientTokenBindingMethod::NOTHING)
    dbsc_status = ClientTokenDbscStatus.find(ClientTokenDbscStatus::NOTHING)

    base_attrs = {
      user: user,
      user_token_kind: token_kind,
      user_token_binding_method: binding_method,
      user_token_dbsc_status: dbsc_status,
    }

    2.times do
      ClientToken.create!(base_attrs.merge(user_token_status: active_status))
    end

    ClientToken.create!(base_attrs.merge(user_token_status: expired_status))
    ClientToken.create!(base_attrs.merge(user_token_status: revoked_status))
    ClientToken.create!(base_attrs.merge(user_token_status: active_status, discarded_at: 1.minute.ago))
    ClientToken.create!(base_attrs.merge(user_token_status: active_status, rotated_at: Time.current))

    extra_token = ClientToken.new(base_attrs.merge(user_token_status: active_status))

    assert_predicate extra_token, :valid?
    assert_difference -> { ClientToken.where(user_id: user.id).count }, 1 do
      extra_token.save!
    end
  end

  test "refresh token digest updates and authenticates" do
    @token.destroy
    token = ClientToken.create!(user: @user)

    token.refresh_token = "verifier-value"
    token.save!

    assert_predicate token.refresh_token_digest, :present?
    assert token.authenticate_refresh_token("verifier-value")
    assert_not token.authenticate_refresh_token("wrong-value")
  end

  test "active state reflects revoked and expired refresh tokens" do
    freeze_time do
      token = ClientToken.create!(user: Client.create!)

      assert_predicate token, :active?

      travel 1.minute
      token.update!(discarded_at: 30.seconds.from_now)

      assert_not token.expired_refresh?
      assert_predicate token, :active?

      token.update_columns(discarded_at: 30.seconds.ago)

      assert_predicate token, :expired_refresh?
      assert_not token.active?
    end
  end

  test "revoke! marks token expired and revoked" do
    token = ClientToken.create!(user: @user)

    token.revoke!

    assert_predicate token, :expired?
    assert_predicate token.discarded_at, :present?
    assert_predicate token.discarded_at, :present?
  end

  test "rotate_refresh_token! updates digest and timestamps" do
    @token.destroy
    token = ClientToken.create!(user: @user)
    old_digest = token.refresh_token_digest

    new_token = token.rotate_refresh_token!

    assert_match(/\A#{token.public_id}\./, new_token)
    assert_not_equal old_digest, token.refresh_token_digest
    assert_predicate token.last_used_at, :present?
  end

  test "rotate_refresh_token! generates token that authenticates" do
    @token.destroy
    token = ClientToken.create!(user: @user)
    raw = token.rotate_refresh_token!

    public_id, verifier = ClientToken.parse_refresh_token(raw)

    assert_equal token.public_id, public_id
    assert token.authenticate_refresh_token(verifier)
    assert_not token.authenticate_refresh_token("wrong-value")
  end

  test "rotated replacement preserves scheduled revocation window" do
    freeze_time do
      token = ClientToken.create!(
        user: @user,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        discarded_at: 3.hours.from_now,
        purged_at: 4.days.from_now,
      )
      token.rotate_refresh_token!

      result = ClientToken.rotate_refresh!(
        presented_refresh_digest: token.refresh_token_digest,
        now: Time.current,
      )
      replacement = result[:token]

      assert_equal :rotated, result[:status]
      assert_equal token.discarded_at.to_i, replacement.discarded_at.to_i
      assert_equal token.purged_at.to_i, replacement.purged_at.to_i
      assert_equal token.oidc_sid, replacement.oidc_sid
      assert_not_equal token.oidc_jti, replacement.oidc_jti
    end
  end

  test "parse_refresh_token splits public_id and verifier" do
    @token.destroy
    token = ClientToken.create!(user: @user)
    raw = token.rotate_refresh_token!

    public_id, verifier = ClientToken.parse_refresh_token(raw)

    assert_equal token.public_id, public_id
    assert_predicate verifier, :present?
  end

  test "does not expose legacy session_id column" do
    assert_not_includes ClientToken.column_names, "session_id"
  end

  test "oidc identifiers are generated separately from token public id" do
    user = Client.create!
    token = ClientToken.create!(user: user)

    assert_predicate token.oidc_sid, :present?
    assert_predicate token.oidc_jti, :present?
    assert_not_equal token.public_id, token.oidc_sid
    assert_not_equal token.oidc_sid, token.oidc_jti
  end

  test "public_id is generated and unique" do
    user = Client.create!
    token1 = ClientToken.create!(user: user)
    token2 = ClientToken.create!(user: user)

    assert_not_equal token1.public_id, token2.public_id
  end

  test "public_id length boundary" do
    @token.public_id = "a" * 22

    assert_not @token.valid?
    assert_not_empty @token.errors[:public_id]
  end

  test "discarded_at is required" do
    @token.discarded_at = nil

    assert_not @token.valid?
    assert_not_empty @token.errors[:discarded_at]
  end

  test "purged_at persists on create when provided" do
    discarded_at = 1.day.from_now
    purged_at = 2.days.from_now
    token = ClientToken.create!(
      user: Client.create!,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: discarded_at,
      purged_at: purged_at,
    )

    assert_equal purged_at.to_i, token.purged_at.to_i
  end

  test "purged_at is preserved when discarded_at changes" do
    purged_at = 4.days.from_now
    token = ClientToken.create!(
      user: Client.create!,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      purged_at: purged_at,
    )
    new_lapses_at = 2.days.from_now

    token.update!(discarded_at: new_lapses_at)

    assert_equal purged_at.to_i, token.purged_at.to_i
  end

  test "purgeability query returns only tokens purgeable at or before now" do
    user = Client.create!
    past_token = ClientToken.create!(user: user, discarded_at: 20.minutes.ago, purged_at: 10.minutes.ago)
    future_token = ClientToken.create!(user: user, discarded_at: 10.minutes.ago, purged_at: 10.minutes.from_now)

    purgeable_ids = ClientToken.where(purged_at: ..Time.current).pluck(:id)

    assert_includes purgeable_ids, past_token.id
    assert_not_includes purgeable_ids, future_token.id
  end

  test "association deletion: destroys when user is destroyed" do
    @token.reload # Ensure it exists
    @user.destroy
    assert_raise(ActiveRecord::RecordNotFound) { @token.reload }
  end

  test "rotate_refresh! consumes old row and creates new generation in same family" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    raw = token.rotate_refresh_token!
    _, verifier = ClientToken.parse_refresh_token(raw)
    digest = ClientToken.digest_refresh_token(verifier)

    result = ClientToken.rotate_refresh!(presented_refresh_digest: digest, now: Time.current)

    assert_equal :rotated, result[:status]
    new_token = result[:token]

    assert_predicate new_token, :present?
    assert_not_equal token.id, new_token.id
    assert_equal token.refresh_token_family_id, new_token.refresh_token_family_id
    assert_equal token.refresh_token_generation + 1, new_token.refresh_token_generation
    assert_nil new_token.rotated_at
    assert_predicate token.reload.rotated_at, :present?
  end

  test "rotate_refresh! rejects blank and unknown digests" do
    assert_equal :invalid,
                 ClientToken.rotate_refresh!(presented_refresh_digest: nil)[:status]
    assert_equal :invalid,
                 ClientToken.rotate_refresh!(
                   presented_refresh_digest: ClientToken.digest_refresh_token("unknown"),
                 )[:status]
  end

  test "rotate_refresh! allows missing presented device id" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    raw = token.rotate_refresh_token!
    digest = ClientToken.digest_refresh_token(ClientToken.parse_refresh_token(raw).last)

    result = ClientToken.rotate_refresh!(presented_refresh_digest: digest, now: Time.current)

    assert_equal :rotated, result[:status]
  end

  test "rotate_refresh_token! preserves a finite absolute expiry and replaces an infinite cutoff" do
    token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
    )
    absolute_expiry = token.discarded_at
    requested_extension = absolute_expiry + 1.day

    token.rotate_refresh_token!(discarded_at: requested_extension)

    assert_equal absolute_expiry.to_i, token.discarded_at.to_i

    token.update_columns(discarded_at: Float::INFINITY)
    token.rotate_refresh_token!

    assert_in_delta 30.days.from_now.to_f, Float(token.discarded_at), 2
    absolute_expiry = token.discarded_at
    token.rotate_refresh_token!(discarded_at: absolute_expiry + 1.day)
    assert_equal absolute_expiry.to_i, token.discarded_at.to_i
  end

  test "refresh token assignment and authentication handle blank values" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    token.refresh_token = ""

    assert_nil token.refresh_token_digest
    assert_not token.authenticate_refresh_token("anything")

    token.refresh_token = "verifier-value"

    assert_not token.refresh_token_digest_matches?(nil)
    assert_not token.refresh_token_digest_matches?("")
  end

  test "rotate_refresh! classifies second attempt as replay" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    raw = token.rotate_refresh_token!
    _, verifier = ClientToken.parse_refresh_token(raw)
    digest = ClientToken.digest_refresh_token(verifier)

    first = ClientToken.rotate_refresh!(presented_refresh_digest: digest, now: Time.current)

    assert_equal :rotated, first[:status]

    second = ClientToken.rotate_refresh!(presented_refresh_digest: digest, now: Time.current)

    assert_equal :replay, second[:status]
    assert_predicate token.reload.rotated_at, :present?
  end

  test "rotate_refresh! classifies rotated token reuse as replay before device mismatch" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    raw = token.rotate_refresh_token!
    digest = ClientToken.digest_refresh_token(ClientToken.parse_refresh_token(raw).last)

    first = ClientToken.rotate_refresh!(presented_refresh_digest: digest, now: Time.current)

    assert_equal :rotated, first[:status]

    second = ClientToken.rotate_refresh!(presented_refresh_digest: digest, now: Time.current)

    assert_equal :replay, second[:status]
    assert_equal token.id, second[:token].id
  end

  test "rotate_refresh! does not require device fallback" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    raw = token.rotate_refresh_token!
    digest = ClientToken.digest_refresh_token(ClientToken.parse_refresh_token(raw).last)
    family_id = token.refresh_token_family_id
    before_count = ClientToken.where(refresh_token_family_id: family_id).count

    result = ClientToken.rotate_refresh!(presented_refresh_digest: digest, now: Time.current)

    assert_equal :rotated, result[:status]
    assert_not_equal token.id, result[:token].id
    token.reload

    assert_predicate token.rotated_at, :present?
    assert_equal before_count + 1, ClientToken.where(refresh_token_family_id: family_id).count
  end

  test "rotate_refresh! rejects revoked compromised and expired tokens" do
    user = Client.create!(public_id: "u_#{SecureRandom.hex(8)}", status_id: ClientStatus::NOTHING)
    revoked = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    compromised = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    expired = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    revoked_raw = revoked.rotate_refresh_token!
    compromised_raw = compromised.rotate_refresh_token!
    expired_raw = expired.rotate_refresh_token!
    travel 1.minute do
      revoked.update_columns(discarded_at: 30.seconds.ago)
      expired.update_columns(discarded_at: 30.seconds.ago)
      compromised.update!(discarded_at: Time.current)

      revoked_digest = ClientToken.digest_refresh_token(ClientToken.parse_refresh_token(revoked_raw).last)
      compromised_digest = ClientToken.digest_refresh_token(ClientToken.parse_refresh_token(compromised_raw).last)
      expired_digest = ClientToken.digest_refresh_token(ClientToken.parse_refresh_token(expired_raw).last)

      assert_equal :invalid,
                   ClientToken.rotate_refresh!(
                     presented_refresh_digest: revoked_digest,
                     now: Time.current,
                   )[:status]
      assert_equal :invalid,
                   ClientToken.rotate_refresh!(
                     presented_refresh_digest: compromised_digest,
                     now: Time.current,
                   )[:status]
      assert_equal :invalid,
                   ClientToken.rotate_refresh!(
                     presented_refresh_digest: expired_digest,
                     now: Time.current,
                   )[:status]
    end
  end

  test "find_from_signed_ref resolves token when verifier payload has string keys" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    signed_ref = Rails.application.message_verifier(:session_ref).generate(
      { "id" => token.id, "pid" => token.public_id },
      expires_in: 1.hour,
    )

    found = ClientToken.find_from_signed_ref(signed_ref)

    assert_equal token.id, found&.id
  end

  test "find_from_signed_ref returns nil for invalid signature" do
    assert_nil ClientToken.find_from_signed_ref("invalid-signed-ref")
  end
end
