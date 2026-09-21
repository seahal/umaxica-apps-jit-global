# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_secret_credentials
# Database name: app_principal
#
#  id                             :bigint           not null, primary key
#  consumed_at                    :datetime
#  delivery_method                :string
#  discard_at                   :datetime         default(Infinity), not null
#  failure_count                  :integer          default(0), not null
#  issued_at                      :datetime
#  issued_by_ref                  :string
#  issued_by_type                 :string
#  last_failed_at                 :datetime
#  last_used_at                   :datetime
#  locked_at                      :datetime
#  lookup_digest                  :string
#  max_failures                   :integer
#  max_uses                       :integer
#  name                           :string           default(""), not null
#  not_before_at                  :datetime
#  password_digest                :string           default(""), not null
#  purge_eligible_at                      :datetime         default(Infinity), not null
#  revoked_at                     :datetime
#  safe_prefix                    :string
#  scope                          :string
#  secret_kind                    :string
#  usage_policy                   :string
#  use_count                      :integer          default(0), not null
#  uses_remaining                 :integer          default(1), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  issued_by_id                   :bigint
#  public_id                      :string(21)       not null
#  user_id                        :bigint           not null
#  user_identity_secret_status_id :bigint           default(1), not null
#  user_secret_kind_id            :bigint           default(1), not null
#
# Indexes
#
#  idx_on_user_identity_secret_status_id_178d36c039        (user_identity_secret_status_id)
#  index_client_secret_credentials_on_lookup_digest        (lookup_digest)
#  index_client_secret_credentials_on_public_id            (public_id) UNIQUE
#  index_client_secret_credentials_on_user_id              (user_id)
#  index_client_secret_credentials_on_user_secret_kind_id  (user_secret_kind_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#  fk_rails_...  (user_identity_secret_status_id => client_secret_credential_statuses.id)
#  fk_rails_...  (user_secret_kind_id => client_secret_credential_kinds.id)
#

require "test_helper"
require "concurrent"

class ClientSecretCredentialTest < ActiveSupport::TestCase
  setup do
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    # Also need ClientSecretCredentialStatus as 'ACTIVE', 'USED', 'EXPIRED' are used in tests
    @active_status = ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::ACTIVE)
    ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::USED)
    ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::EXPIRED)
    # Set up ClientSecretCredentialKind records
    @login_kind = ClientSecretCredentialKind.find_or_create_by!(id: ClientSecretCredentialKind::LOGIN)
    ClientSecretCredentialKind.find_or_create_by!(id: ClientSecretCredentialKind::TOTP)
    ClientSecretCredentialKind.find_or_create_by!(id: ClientSecretCredentialKind::RECOVERY)
    ClientSecretCredentialKind.find_or_create_by!(id: ClientSecretCredentialKind::API)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)

    @user =
      Client.create!(public_id: "u_#{SecureRandom.hex(8)}") do |u|
        u.status_id = ClientStatus::NOTHING
      end
    ClientEmail.create!(
      user: @user,
      address: "secret_credential-model-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    # Preload to avoid N+1 in validations
    @user.client_emails.load
    @user.client_secret_credentials.load
  end

  test "allows up to the maximum number of secret_credentials per user" do
    ClientSecretCredential::MAX_SECRETS_PER_USER.times do
      create_secret_credential!
    end

    assert_equal ClientSecretCredential::MAX_SECRETS_PER_USER,
                 ClientSecretCredential.where(user: @user).count
  end

  test "rejects creating more than the maximum secret_credentials per user" do
    ClientSecretCredential::MAX_SECRETS_PER_USER.times { create_secret_credential! }

    assert_raises(ActiveRecord::RecordInvalid) { create_secret_credential! }
  end

  test "issue! returns raw secret_credential and persists a digest" do
    record, raw_secret_credential = ClientSecretCredential.issue!(name: "API Key", user: @user, user_secret_kind_id: ClientSecretCredentialKind::LOGIN)

    assert_predicate record, :persisted?
    assert_predicate raw_secret_credential, :present?
    assert record.authenticate(raw_secret_credential)
    assert_not_includes record.attributes.values, raw_secret_credential
  end

  test "verify_and_consume! decrements uses_remaining" do
    record, raw_secret_credential = ClientSecretCredential.issue!(
      name: "API Key", user: @user, uses: 2,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )

    assert record.verify_and_consume!(raw_secret_credential)
    assert_equal 1, record.reload.uses_remaining
  end

  test "verify_and_consume! marks used when uses_remaining reaches zero" do
    record, raw_secret_credential = ClientSecretCredential.issue!(
      name: "API Key", user: @user, uses: 1,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )

    assert record.verify_and_consume!(raw_secret_credential)
    assert_equal ClientSecretCredentialStatus::USED, record.reload.user_secret_status_id
  end

  test "verify_and_consume! expires secret_credentials past their expiry" do
    record, raw_secret_credential = ClientSecretCredential.issue!(
      name: "API Key",
      user: @user,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )
    record.update_columns(discard_at: 1.minute.ago, created_at: 2.minutes.ago)

    assert_not record.verify_and_consume!(raw_secret_credential)
    assert_equal ClientSecretCredentialStatus::EXPIRED, record.reload.user_secret_status_id
  end

  test "verify_and_consume! only allows one consumer for a single use" do
    record, raw_secret_credential = ClientSecretCredential.issue!(
      name: "API Key", user: @user, uses: 1,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )
    gate = Queue.new

    futures =
      2.times.map do
        Concurrent::Future.execute do
          ActiveRecord::Base.connection_pool.with_connection do
            gate.pop
            ClientSecretCredential.find(record.id).verify_and_consume!(raw_secret_credential)
          end
        end
      end

    2.times { gate << true }
    results = futures.map(&:value!)

    assert_equal 1, results.count(true)
    assert_equal 0, record.reload.uses_remaining
  end

  test "invalid when password_digest is nil" do
    record = ClientSecretCredential.new(user: @user, name: "Key", password: nil)

    assert_not record.valid?
    assert_not_empty record.errors[:password_digest]
  end

  test "name length boundary" do
    record = ClientSecretCredential.new(user: @user, name: "a" * 256, password: "SecretPass123!")

    assert_not record.valid?
    assert_not_empty record.errors[:name]
  end

  test "association deletion: destroys when user is destroyed" do
    record, _raw = ClientSecretCredential.issue!(name: "Cleanup Test", user: @user, user_secret_kind_id: ClientSecretCredentialKind::LOGIN)
    @user.destroy
    assert_raise(ActiveRecord::RecordNotFound) { record.reload }
  end

  test "generate_raw_secret_credential returns base58 string of expected length" do
    secret_credential = ClientSecretCredential.generate_raw_secret_credential(length: 32)

    assert_equal 32, secret_credential.length
    assert_match(/\A[1-9A-HJ-NP-Za-km-z]+\z/, secret_credential)
  end

  test "sample fixture secret_credential authenticates with fixed raw secret_credential" do
    secret_credential = client_secret_credentials(:sample_login)

    assert secret_credential.authenticate("00000000000000000000000000000000")
    assert_equal ClientSecretCredentialKind::PERMANENT, secret_credential.user_secret_kind_id
    assert_equal ClientSecretCredentialStatus::ACTIVE, secret_credential.user_secret_status_id
  end

  test "value maps to password accessor" do
    record = ClientSecretCredential.new(user: @user, name: "Key")

    record.value = secure_secret_credential

    assert_equal record.password, record.value
  end

  test "enabled? reflects active status" do
    record = ClientSecretCredential.new(user: @user, name: "Key")
    record.user_secret_status_id = ClientSecretCredentialStatus::ACTIVE

    assert_predicate record, :enabled?

    record.user_secret_status_id = ClientSecretCredentialStatus::REVOKED

    assert_not record.enabled?
  end

  test "usable_for_secret_credential_sign_in? rejects revoked kind and expired secret_credentials" do
    record, _raw = ClientSecretCredential.issue!(name: "Sign In Secret", user: @user, user_secret_kind_id: ClientSecretCredentialKind::LOGIN)

    assert_predicate record, :usable_for_secret_credential_sign_in?

    record.user_identity_secret_status_id = ClientSecretCredentialStatus::REVOKED

    assert_not record.usable_for_secret_credential_sign_in?

    record.user_identity_secret_status_id = ClientSecretCredentialStatus::ACTIVE
    record.user_secret_kind_id = ClientSecretCredentialKind::TOTP

    assert_not record.usable_for_secret_credential_sign_in?

    record.user_secret_kind_id = ClientSecretCredentialKind::LOGIN
    record.define_singleton_method(:discard_at) { 1.minute.ago }

    assert_not record.usable_for_secret_credential_sign_in?

    record.define_singleton_method(:discard_at) { nil }

    assert_predicate record, :usable_for_secret_credential_sign_in?
  end

  test "verify_for_secret_credential_sign_in! rejects wrong secret_credential and disallowed states" do
    record, raw_secret_credential = ClientSecretCredential.issue!(
      name: "Sign In Secret", user: @user,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )

    assert_not record.verify_for_secret_credential_sign_in!("wrong-secret_credential")

    record.update!(user_identity_secret_status_id: ClientSecretCredentialStatus::REVOKED)

    assert_not record.verify_for_secret_credential_sign_in!(raw_secret_credential)

    record.update!(
      user_identity_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
      user_secret_kind_id: ClientSecretCredentialKind::TOTP,
    )

    assert_not record.verify_for_secret_credential_sign_in!(raw_secret_credential)
  end

  test "validates kind_id is required" do
    record = ClientSecretCredential.new(
      user: @user,
      name: "Test Secret",
      password: secure_secret_credential,
      user_secret_kind_id: nil,
    )

    assert_not record.valid?
    assert_not_empty record.errors[:user_secret_credential_kind]
  end

  test "login_secret_credential? predicate returns true for LOGIN kind" do
    record = ClientSecretCredential.new(user: @user, name: "Key", user_secret_kind_id: ClientSecretCredentialKind::LOGIN)

    assert_predicate record, :login_secret_credential?
    assert_not record.totp_secret_credential?
    assert_not record.recovery_secret_credential?
    assert_not record.api_secret_credential?
  end

  test "totp_secret_credential? predicate returns true for TOTP kind" do
    record = ClientSecretCredential.new(user: @user, name: "Key", user_secret_kind_id: ClientSecretCredentialKind::TOTP)

    assert_predicate record, :totp_secret_credential?
    assert_not record.login_secret_credential?
  end

  test "recovery_secret_credential? predicate returns true for RECOVERY kind" do
    record = ClientSecretCredential.new(user: @user, name: "Key", user_secret_kind_id: ClientSecretCredentialKind::RECOVERY)

    assert_predicate record, :recovery_secret_credential?
    assert_not record.login_secret_credential?
  end

  test "api_secret_credential? predicate returns true for API kind" do
    record = ClientSecretCredential.new(user: @user, name: "Key", user_secret_kind_id: ClientSecretCredentialKind::API)

    assert_predicate record, :api_secret_credential?
    assert_not record.login_secret_credential?
  end

  test "public_id is automatically generated on create" do
    record = ClientSecretCredential.create!(
      user: @user,
      name: "Test Secret",
      password: secure_secret_credential,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )

    assert_predicate record.public_id, :present?
    assert_equal 21, record.public_id.length
  end

  test "to_param returns public_id" do
    record = ClientSecretCredential.create!(
      user: @user,
      name: "Test Secret",
      password: secure_secret_credential,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )

    assert_equal record.public_id, record.to_param
  end

  test "public_id is unique" do
    record1 = ClientSecretCredential.create!(
      user: @user,
      name: "Test Secret 1",
      password: secure_secret_credential,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )

    record2 = ClientSecretCredential.new(
      user: @user,
      name: "Test Secret 2",
      password: secure_secret_credential,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )
    record2.public_id = record1.public_id

    assert_not record2.valid?
    assert_not_empty record2.errors[:public_id]
  end

  test "is invalid on create when user has no verified recovery identity" do
    user_without_identity =
      Client.create!(public_id: "u_#{SecureRandom.hex(8)}") do |u|
        u.status_id = ClientStatus::NOTHING
      end

    record = ClientSecretCredential.new(
      user: user_without_identity,
      name: "No Identity Secret",
      password: secure_secret_credential,
      password_confirmation: secure_secret_credential,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )

    assert_not record.valid?
    assert_includes record.errors[:base], Client::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  private

  def create_secret_credential!
    ClientSecretCredential.create!(
      user: @user,
      name: "Secret-#{SecureRandom.hex(4)}",
      password: secure_secret_credential,
      password_confirmation: secure_secret_credential,
      user_secret_credential_kind: @login_kind,
      user_secret_credential_status: @active_status,
    )
  end

  def secure_secret_credential
    SecureRandom.base58(SecretCredential::SECRET_PASSWORD_LENGTH)
  end
end
