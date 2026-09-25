# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_tokens
# Database name: org_ticket
#
#  id                                 :bigint           not null, primary key
#  dbsc_challenge                     :text
#  dbsc_challenge_issued_at           :datetime
#  dbsc_public_key                    :jsonb
#  discard_at                       :datetime         default(Infinity), not null
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
#  purge_eligible_at                          :datetime         default(Infinity), not null
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
#  selected_collective_public_id      :string
#  selected_collective_unit_public_id :string
#  staff_id                           :bigint           not null
#  staff_token_binding_method_id      :bigint           default(0), not null
#  staff_token_dbsc_status_id         :bigint           default(0), not null
#  staff_token_kind_id                :bigint           default(1), not null
#  staff_token_status_id              :bigint           default(1), not null
#
# Indexes
#
#  index_operator_tokens_on_created_at                     (created_at)
#  index_operator_tokens_on_dbsc_session_id                (dbsc_session_id) UNIQUE
#  index_operator_tokens_on_device_session_id              (device_session_id)
#  index_operator_tokens_on_discard_at                   (discard_at)
#  index_operator_tokens_on_oidc_connection_id             (oidc_connection_id)
#  index_operator_tokens_on_oidc_jti                       (oidc_jti)
#  index_operator_tokens_on_oidc_sid                       (oidc_sid)
#  index_operator_tokens_on_public_id                      (public_id) UNIQUE
#  index_operator_tokens_on_purge_eligible_at                      (purge_eligible_at)
#  index_operator_tokens_on_refresh_token_digest           (refresh_token_digest) UNIQUE
#  index_operator_tokens_on_refresh_token_family_id        (refresh_token_family_id)
#  index_operator_tokens_on_rotated_at                     (rotated_at)
#  index_operator_tokens_on_selected_account_public_id     (selected_account_public_id)
#  index_operator_tokens_on_selected_collective_public_id  (selected_collective_public_id)
#  index_operator_tokens_on_staff_id_and_last_step_up_at   (staff_id,last_step_up_at)
#  index_operator_tokens_on_staff_id_and_oidc_client_id    (staff_id,oidc_client_id)
#  index_operator_tokens_on_staff_token_binding_method_id  (staff_token_binding_method_id)
#  index_operator_tokens_on_staff_token_dbsc_status_id     (staff_token_dbsc_status_id)
#  index_operator_tokens_on_staff_token_kind_id            (staff_token_kind_id)
#  index_operator_tokens_on_staff_token_status_id          (staff_token_status_id)
#
# Foreign Keys
#
#  fk_rails_...                                      (staff_token_kind_id => operator_token_kinds.id) ON DELETE => restrict
#  fk_rails_...                                      (staff_token_status_id => operator_token_statuses.id) ON DELETE => restrict
#  fk_staff_tokens_on_staff_token_binding_method_id  (staff_token_binding_method_id => operator_token_binding_methods.id)
#  fk_staff_tokens_on_staff_token_dbsc_status_id     (staff_token_dbsc_status_id => operator_token_dbsc_statuses.id)
#
require "test_helper"

class OperatorTokenTest < ActiveSupport::TestCase
  def setup
    @staff = Operator.create!(staff_status: OperatorStatus.find(OperatorStatus::NOTHING))

    @token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
  end

  test "inherits from OrgTicketRecord" do
    assert_operator OperatorToken, :<, OrgTicketRecord
  end

  test "belongs to staff" do
    association = OperatorToken.reflect_on_association(:staff)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
  end

  test "can be created with staff" do
    assert_not_nil @token
    assert_equal @staff.id, @token.staff_id
  end

  test "device session rejects a current token owned by another session" do
    other_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    session = @token.device_session

    error =
      assert_raises(ActiveRecord::InvalidForeignKey) do
        OperatorDeviceSession.transaction(requires_new: true) do
          session.update_column(:current_refresh_token_id, other_token.id)
          OperatorDeviceSession.lease_connection.execute(
            "SET CONSTRAINTS fk_operator_device_sessions_on_current_refresh_token_owner IMMEDIATE",
          )
        end
      end
    assert_equal "23503", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_equal "fk_operator_device_sessions_on_current_refresh_token_owner",
                 error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
  end

  test "token device session reference must exist while remaining nullable" do
    missing_session_id = OperatorDeviceSession.lease_connection.select_value(
      "SELECT nextval(pg_get_serial_sequence('operator_device_sessions', 'id'))",
    )

    error =
      assert_raises(ActiveRecord::InvalidForeignKey) do
        OperatorToken.transaction(requires_new: true) do
          @token.update_column(:device_session_id, missing_session_id)
        end
      end
    assert_equal "23503", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_includes %w(fk_operator_tokens_on_device_session_id fk_operator_tokens_on_staff_id_and_device_session_id),
                    error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)

    @token.update_column(:device_session_id, nil)

    assert_nil @token.reload.device_session_id
  end

  test "token device session must belong to the same staff" do
    other_staff = Operator.create!(staff_status: OperatorStatus.find(OperatorStatus::NOTHING))
    other_token = OperatorToken.create!(staff: other_staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    error =
      assert_raises(ActiveRecord::InvalidForeignKey) do
        OperatorToken.transaction(requires_new: true) do
          @token.update_column(:device_session_id, other_token.device_session_id)
        end
      end
    assert_equal "23503", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_equal "fk_operator_tokens_on_staff_id_and_device_session_id",
                 error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
  end

  test "deleting the current token clears only its session pointer" do
    session = @token.device_session
    session.update!(current_refresh_token: @token)

    @token.delete

    assert_nil session.reload.current_refresh_token_id
    assert_predicate session, :persisted?
  end

  test "device session cannot be destroyed while token history references it" do
    session = @token.device_session

    assert_raises(ActiveRecord::DeleteRestrictionError) { session.destroy! }

    error =
      assert_raises(ActiveRecord::InvalidForeignKey) do
        OperatorDeviceSession.transaction(requires_new: true) do
          OperatorDeviceSession.where(id: session.id).delete_all
        end
      end
    assert_equal "23503", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_includes %w(fk_operator_tokens_on_device_session_id fk_operator_tokens_on_staff_id_and_device_session_id),
                    error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)

    assert OperatorDeviceSession.exists?(session.id)
    assert OperatorToken.exists?(@token.id)
  end

  test "destroying the operator removes tokens before its device sessions" do
    session_id = @token.device_session.id

    @staff.destroy!

    assert_not OperatorToken.exists?(@token.id)
    assert_not OperatorDeviceSession.exists?(session_id)
  end

  test "does not expose legacy session_id column" do
    assert_not_includes OperatorToken.column_names, "session_id"
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

  test "staff association loads staff correctly" do
    assert_equal @staff, @token.staff
    assert_equal @staff.id, @token.staff.id
  end

  test "can load one fixture" do
    token_one = OperatorToken.find_by!(public_id: "one_staff_token_00001")

    assert_not_nil token_one
    assert_not_nil token_one.staff_id
  end

  test "can load two fixture" do
    token_two = OperatorToken.find_by!(public_id: "two_staff_token_00001")

    assert_not_nil token_two
    assert_not_nil token_two.staff_id
  end

  test "timestamp is set on creation" do
    assert_not_nil @token.created_at
    assert_not_nil @token.updated_at
    assert_operator @token.created_at, :<=, @token.updated_at
  end

  test "timestamp updates on save" do
    original_updated_at = @token.updated_at
    travel 1.second do
      @token.update!(updated_at: Time.current)
    end

    assert_operator @token.updated_at, :>, original_updated_at
  end

  test "enforces maximum concurrent sessions per staff" do
    staff = Operator.create!(staff_status: OperatorStatus.find(OperatorStatus::NOTHING))
    token_status = OperatorTokenStatus.find(OperatorTokenStatus::ACTIVE)
    token_kind = OperatorTokenKind.find(OperatorTokenKind::BROWSER_WEB)
    binding_method = OperatorTokenBindingMethod.find(OperatorTokenBindingMethod::NOTHING)
    dbsc_status = OperatorTokenDbscStatus.find(OperatorTokenDbscStatus::NOTHING)

    OperatorToken::MAX_TOTAL_SESSIONS_PER_STAFF.times do
      OperatorToken.create!(
        staff: staff,
        staff_token_status: token_status,
        staff_token_kind: token_kind,
        staff_token_binding_method: binding_method,
        staff_token_dbsc_status: dbsc_status,
      )
    end

    extra_token = OperatorToken.new(
      staff: staff,
      staff_token_status: token_status,
      staff_token_kind: token_kind,
      staff_token_binding_method: binding_method,
      staff_token_dbsc_status: dbsc_status,
    )

    assert_not extra_token.valid?
    assert_includes extra_token.errors[:base],
                    "exceeds maximum concurrent sessions per staff (#{OperatorToken::MAX_TOTAL_SESSIONS_PER_STAFF})"
  end

  test "refresh token digest updates and authenticates" do
    @token.refresh_token = "verifier-value"
    @token.save!

    assert_predicate @token.refresh_token_digest, :present?
    assert @token.authenticate_refresh_token("verifier-value")
    assert_not @token.authenticate_refresh_token("wrong-value")
  end

  test "active state reflects revoked and expired refresh tokens" do
    freeze_time do
      token = OperatorToken.create!(staff: @staff)

      assert_predicate token, :active?

      travel 1.minute
      token.update!(discard_at: 30.seconds.from_now)

      assert_not token.expired_refresh?
      assert_predicate token, :active?

      token.update_columns(discard_at: 30.seconds.ago)

      assert_predicate token, :expired_refresh?
      assert_not token.active?
    end
  end

  test "rotate_refresh_token! updates digest and timestamps" do
    old_digest = @token.refresh_token_digest

    new_token = @token.rotate_refresh_token!

    assert_match(/\A#{@token.public_id}\./, new_token)
    assert_not_equal old_digest, @token.refresh_token_digest
    assert_predicate @token.last_used_at, :present?
  end

  test "rotate_refresh_token! generates token that authenticates" do
    raw = @token.rotate_refresh_token!

    public_id, verifier = OperatorToken.parse_refresh_token(raw)

    assert_equal @token.public_id, public_id
    assert @token.authenticate_refresh_token(verifier)
    assert_not @token.authenticate_refresh_token("wrong-value")
  end

  test "rotated replacement preserves forced logout window" do
    freeze_time do
      token = OperatorToken.create!(
        staff: @staff,
        staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        discard_at: 12.hours.from_now,
        purge_eligible_at: 4.days.from_now,
      )
      token.rotate_refresh_token!

      result = OperatorToken.rotate_refresh!(
        presented_refresh_digest: token.refresh_token_digest,
        now: Time.current,
      )
      replacement = result[:token]

      assert_equal :rotated, result[:status]
      assert_equal token.discard_at.to_i, replacement.discard_at.to_i
      assert_equal token.purge_eligible_at.to_i, replacement.purge_eligible_at.to_i
    end
  end

  test "parse_refresh_token splits public_id and verifier" do
    raw = @token.rotate_refresh_token!

    public_id, verifier = OperatorToken.parse_refresh_token(raw)

    assert_equal @token.public_id, public_id
    assert_predicate verifier, :present?
  end

  test "purge_eligible_at persists on create when provided" do
    purge_eligible_at = 2.days.from_now
    token = OperatorToken.create!(
      staff: @staff,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: 1.day.from_now,
      purge_eligible_at: purge_eligible_at,
    )

    assert_equal purge_eligible_at.to_i, token.purge_eligible_at.to_i
  end

  test "purge_eligible_at is preserved when discard_at changes" do
    purge_eligible_at = 4.days.from_now
    token = OperatorToken.create!(
      staff: @staff,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: 1.day.from_now,
      purge_eligible_at: purge_eligible_at,
    )
    new_lapses_at = 2.days.from_now

    token.update!(discard_at: new_lapses_at)

    assert_equal purge_eligible_at.to_i, token.purge_eligible_at.to_i
  end

  test "purgeability query returns only tokens purgeable at or before now" do
    staff = Operator.create!(staff_status: OperatorStatus.find(OperatorStatus::NOTHING))
    past_token = OperatorToken.create!(staff: staff, discard_at: 20.minutes.ago, purge_eligible_at: 10.minutes.ago)
    future_token = OperatorToken.create!(
      staff: staff,
      discard_at: 10.minutes.ago,
      purge_eligible_at: 10.minutes.from_now,
    )

    purgeable_ids = OperatorToken.where(purge_eligible_at: ..Time.current).pluck(:id)

    assert_includes purgeable_ids, past_token.id
    assert_not_includes purgeable_ids, future_token.id
  end

  test "sha3 digest matches hexdigest packed bytes" do
    raw1 = @token.send(:digest_refresh_token, "B")
    hex = SHA3::Digest::SHA3_384.hexdigest("B")
    raw2 = [hex].pack("H*")

    assert ActiveSupport::SecurityUtils.secure_compare(raw1, raw2)
  end

  test "rotate_refresh! consumes old row and creates new generation in same family" do
    token = OperatorToken.create!(
      staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    raw = token.rotate_refresh_token!
    _, verifier = OperatorToken.parse_refresh_token(raw)
    digest = OperatorToken.digest_refresh_token(verifier)

    result = OperatorToken.rotate_refresh!(
      presented_refresh_digest: digest,
      now: Time.current,
    )

    assert_equal :rotated, result[:status]
    new_token = result[:token]

    assert_predicate new_token, :present?
    assert_not_equal token.id, new_token.id
    assert_equal token.refresh_token_family_id, new_token.refresh_token_family_id
    assert_equal token.refresh_token_generation + 1, new_token.refresh_token_generation
    assert_predicate token.reload.rotated_at, :present?
  end

  test "rotate_refresh! classifies second attempt as replay" do
    token = OperatorToken.create!(
      staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    raw = token.rotate_refresh_token!
    _, verifier = OperatorToken.parse_refresh_token(raw)
    digest = OperatorToken.digest_refresh_token(verifier)

    first = OperatorToken.rotate_refresh!(
      presented_refresh_digest: digest,
      now: Time.current,
    )

    assert_equal :rotated, first[:status]

    second = OperatorToken.rotate_refresh!(
      presented_refresh_digest: digest,
      now: Time.current,
    )

    assert_equal :replay, second[:status]
    assert_predicate token.reload.rotated_at, :present?
  end

  test "rotate_refresh! rejects revoked compromised and expired tokens" do
    revoked_staff = Operator.create!(staff_status: OperatorStatus.find(OperatorStatus::NOTHING))
    compromised_staff = Operator.create!(staff_status: OperatorStatus.find(OperatorStatus::NOTHING))
    expired_staff = Operator.create!(staff_status: OperatorStatus.find(OperatorStatus::NOTHING))
    revoked = OperatorToken.create!(
      staff: revoked_staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    compromised = OperatorToken.create!(
      staff: compromised_staff,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    expired = OperatorToken.create!(
      staff: expired_staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    revoked_raw = revoked.rotate_refresh_token!
    compromised_raw = compromised.rotate_refresh_token!
    expired_raw = expired.rotate_refresh_token!
    travel 1.minute do
      revoked.update_columns(discard_at: 30.seconds.ago)
      expired.update_columns(discard_at: 30.seconds.ago)
      compromised.update!(discard_at: Time.current)

      revoked_digest = OperatorToken.digest_refresh_token(OperatorToken.parse_refresh_token(revoked_raw).last)
      compromised_digest = OperatorToken.digest_refresh_token(OperatorToken.parse_refresh_token(compromised_raw).last)
      expired_digest = OperatorToken.digest_refresh_token(OperatorToken.parse_refresh_token(expired_raw).last)

      assert_equal :invalid,
                   OperatorToken.rotate_refresh!(
                     presented_refresh_digest: revoked_digest,
                     now: Time.current,
                   )[:status]
      assert_equal :invalid,
                   OperatorToken.rotate_refresh!(
                     presented_refresh_digest: compromised_digest,
                     now: Time.current,
                   )[:status]
      assert_equal :invalid,
                   OperatorToken.rotate_refresh!(
                     presented_refresh_digest: expired_digest,
                     now: Time.current,
                   )[:status]
    end
  end

  test "find_from_signed_ref resolves token when verifier payload has string keys" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    signed_ref = Rails.application.message_verifier(:session_ref).generate(
      { "id" => token.id, "pid" => token.public_id },
      expires_in: 1.hour,
    )

    found = OperatorToken.find_from_signed_ref(signed_ref)

    assert_equal token.id, found&.id
  end

  test "find_from_signed_ref returns nil for invalid signature" do
    assert_nil OperatorToken.find_from_signed_ref("invalid-signed-ref")
  end
end
