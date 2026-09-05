# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_totp_credentials
# Database name: app_principal
#
#  id                                      :bigint           not null, primary key
#  last_otp_at                             :datetime         default(-Infinity), not null
#  private_key                             :string(1024)     default(""), not null
#  title                                   :string(32)
#  created_at                              :datetime         not null
#  updated_at                              :datetime         not null
#  public_id                               :string(21)       not null
#  user_id                                 :bigint           not null
#  user_identity_totp_credential_status_id :bigint           default(5), not null
#
# Indexes
#
#  idx_on_user_identity_totp_credential_status_id_47a8d28ad3  (user_identity_totp_credential_status_id)
#  index_client_totp_credentials_on_public_id                 (public_id) UNIQUE
#  index_client_totp_credentials_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#  fk_rails_...  (user_identity_totp_credential_status_id => client_totp_credential_statuses.id)
#

require "test_helper"

class ClientTotpCredentialTest < ActiveSupport::TestCase
  def setup
    @user = Client.create!(public_id: "u_#{SecureRandom.hex(8)}", status_id: ClientStatus::NOTHING)
    ClientTotpCredentialStatus.find_or_create_by!(id: ClientTotpCredentialStatus::NOTHING)
    @status = ClientTotpCredentialStatus.find(ClientTotpCredentialStatus::ACTIVE)

    @private_key = "test-secret_credential-key-12345"
    @last_otp_at = Time.current
  end

  test "inherits from AppPrincipalRecord" do
    assert_operator ClientTotpCredential, :<, AppPrincipalRecord
  end

  test "belongs to user" do
    association = ClientTotpCredential.reflect_on_association(:user)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
  end

  test "belongs to user_totp_credential_status" do
    association = ClientTotpCredential.reflect_on_association(:user_totp_credential_status)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
  end

  test "has private_key attribute" do
    record = ClientTotpCredential.new(
      user: @user,
      private_key: @private_key,
      last_otp_at: @last_otp_at,
    )

    assert_equal @private_key, record.private_key
  end

  test "persists private_key encrypted at rest" do
    record = ClientTotpCredential.create!(
      user: @user,
      private_key: @private_key,
      last_otp_at: @last_otp_at,
    )

    raw_private_key =
      ClientTotpCredential.connection.select_value(
        ClientTotpCredential.where(id: record.id).select(:private_key).to_sql,
      )

    assert_not_equal @private_key, raw_private_key
    assert_not_equal @private_key, record.reload.read_attribute_before_type_cast("private_key")
  end

  test "verifies totp codes after encryption" do
    secret = ROTP::Base32.random_base32
    # The code is generated before the record is written and verified after, so the
    # clock is pinned -- otherwise the 30-second TOTP window can turn over in between.
    freeze_time do
      token = ROTP::TOTP.new(secret).now

      record = ClientTotpCredential.create!(
        user: @user,
        private_key: secret,
        last_otp_at: @last_otp_at,
      )

      assert_not_equal secret, record.reload.read_attribute_before_type_cast("private_key")
      assert ROTP::TOTP.new(record.private_key).verify(token)
    end
  end

  test "has last_otp_at attribute" do
    record = ClientTotpCredential.new(
      user: @user,
      private_key: @private_key,
      last_otp_at: @last_otp_at,
    )

    # Compare timestamps ignoring nanosecond precision
    assert_in_delta @last_otp_at, record.last_otp_at, 1.second
  end

  test "auto-generates private_key if blank" do
    record = ClientTotpCredential.new(
      user: @user,
      last_otp_at: @last_otp_at,
    )

    # Private key should be generated automatically
    assert_not_nil record.private_key
    assert_predicate record, :valid?
  end

  test "validates presence of last_otp_at" do
    record = ClientTotpCredential.new(
      user: @user,
      private_key: @private_key,
      last_otp_at: nil,
    )

    assert_not record.valid?
    assert_not_empty record.errors[:last_otp_at]
  end

  test "validates private_key length maximum" do
    record = ClientTotpCredential.new(
      user: @user,
      private_key: "x" * 1025,
      last_otp_at: @last_otp_at,
    )

    assert_not record.valid?
    assert_not_empty record.errors[:private_key]
  end

  test "enforces maximum totp records per user" do
    new_user = Client.create!(
      status_id: ClientStatus::NOTHING,
    )
    status = ClientTotpCredentialStatus.find(ClientTotpCredentialStatus::NOTHING)

    ClientTotpCredential::MAX_TOTPS_PER_USER.times do
      ClientTotpCredential.create!(
        user: new_user,
        user_totp_credential_status: status,
        private_key: ROTP::Base32.random_base32,
        last_otp_at: Time.current,
      )
    end

    extra_totp = ClientTotpCredential.new(
      user: new_user,
      user_totp_credential_status: status,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.current,
    )

    assert_not extra_totp.valid?
    assert_includes extra_totp.errors[:base], "exceeds maximum totps per user (#{ClientTotpCredential::MAX_TOTPS_PER_USER})"
  end

  test "association deletion: destroys when user is destroyed" do
    record = ClientTotpCredential.create!(user: @user)
    @user.destroy
    assert_raise(ActiveRecord::RecordNotFound) { record.reload }
  end
end
