# typed: false
# frozen_string_literal: true

module SecretCredential
  extend ActiveSupport::Concern

  SECRET_PASSWORD_LENGTH = 32
  NEW_SECRET_KINDS = %w(
    recovery
    operator_issued_recovery
    temporary_access
    persistent_access
    mailed_activation
  ).freeze
  NEW_USAGE_POLICIES = %w(
    single_use
    multi_use
    limited_session
  ).freeze

  included do
    has_secure_password algorithm: :argon2, validations: false
    validates :name, presence: true
    validates :password,
              length: {
                is: SECRET_PASSWORD_LENGTH,
                message: "must be #{SECRET_PASSWORD_LENGTH} characters",
              },
              allow_nil: true
    validate :new_axis_secret_fields_are_consistent
  end

  class_methods do
    def issue!(name:, length: SECRET_PASSWORD_LENGTH, discard_at: nil, uses: 1, status: :active, **attributes)
      raw_secret_credential = SecureRandom.base58(length)
      record_attributes = attributes.merge(name: name)
      record_attributes[:uses_remaining] = uses if supports_uses_remaining?
      record_attributes[:discard_at] = discard_at if discard_at && supports_expiration?
      record = new(record_attributes)
      record[identity_secret_credential_status_id_column] = status_id_for(status)
      record.password = raw_secret_credential
      record.save!
      [record, raw_secret_credential]
    end

    def identity_secret_credential_status_class
      raise NotImplementedError, "define identity_secret_credential_status_class in the including model"
    end

    def identity_secret_credential_status_id_column
      raise NotImplementedError, "define identity_secret_credential_status_id_column in the including model"
    end

    def status_id_for(status)
      status_key = status.to_s.upcase
      case identity_secret_credential_status_class.name
      when "OperatorSecretCredentialStatus"
        {
          "ACTIVE" => OperatorSecretCredentialStatus::ACTIVE,
          "DELETED" => OperatorSecretCredentialStatus::DELETED,
          "EXPIRED" => OperatorSecretCredentialStatus::EXPIRED,
          "REVOKED" => OperatorSecretCredentialStatus::REVOKED,
          "USED" => OperatorSecretCredentialStatus::USED,
        }.fetch(status_key)
      when "VisitorSecretCredentialStatus"
        {
          "ACTIVE" => VisitorSecretCredentialStatus::ACTIVE,
          "EXPIRED" => VisitorSecretCredentialStatus::EXPIRED,
          "REVOKED" => VisitorSecretCredentialStatus::REVOKED,
          "USED" => VisitorSecretCredentialStatus::USED,
          "DELETED" => VisitorSecretCredentialStatus::DELETED,
          "NOTHING" => VisitorSecretCredentialStatus::NOTHING,
        }.fetch(status_key)
      else
        raise KeyError,
              "Unknown identity secret_credential status class: #{identity_secret_credential_status_class.name}"
      end
    end

    def supports_uses_remaining?
      if respond_to?(:column_names)
        column_names.include?("uses_remaining")
      elsif respond_to?(:attribute_types)
        attribute_types.key?("uses_remaining")
      else
        false
      end
    end

    def supports_expiration?
      if respond_to?(:column_names)
        column_names.include?("discard_at")
      elsif respond_to?(:attribute_types)
        attribute_types.key?("discard_at")
      else
        false
      end
    end
  end

  def expire_if_needed!(now: Time.current)
    return false unless active?
    return false unless expired_by_time?(now)

    self[self.class.identity_secret_credential_status_id_column] = self.class.status_id_for(:expired)
    save!
    true
  end

  def active?
    secret_credential_status_id == self.class.identity_secret_credential_status_class::ACTIVE
  end

  def used?
    secret_credential_status_id == self.class.identity_secret_credential_status_class::USED
  end

  def revoked?
    secret_credential_status_id == self.class.identity_secret_credential_status_class::REVOKED
  end

  def expired?
    secret_credential_status_id == self.class.identity_secret_credential_status_class::EXPIRED
  end

  def deleted?
    secret_credential_status_id == self.class.identity_secret_credential_status_class::DELETED
  end

  def new_axis_secret_credential?
    return false unless respond_to?(:secret_kind)
    return true if secret_kind.present?
    return true if respond_to?(:lookup_digest) && lookup_digest.present?
    return true if respond_to?(:usage_policy) && usage_policy.present?

    false
  end

  private

  def secret_credential_status_id
    self[self.class.identity_secret_credential_status_id_column]
  end

  def uses_remaining_available?
    respond_to?(:uses_remaining) && self.class.supports_uses_remaining?
  end

  def expired_by_time?(now)
    return false unless respond_to?(:discard_at)
    return false if discard_at.nil?

    # PostgreSQL infinity/-infinity are used as sentinels for "never expires"
    # When read from DB, they may be converted to Float::INFINITY/-Float::INFINITY
    return false if discard_at.respond_to?(:infinite?) && discard_at.infinite?

    discard_at <= now
  end

  private

  def new_axis_secret_fields_are_consistent
    return unless new_axis_secret_credential?

    if respond_to?(:secret_kind) && secret_kind.present? && NEW_SECRET_KINDS.exclude?(secret_kind.to_s)
      errors.add(:secret_kind, "is invalid")
    end
    errors.add(:secret_kind, "can't be blank") if respond_to?(:secret_kind) && secret_kind.blank?

    if respond_to?(:usage_policy) && usage_policy.present? && NEW_USAGE_POLICIES.exclude?(usage_policy.to_s)
      errors.add(:usage_policy, "is invalid")
    end
    errors.add(:usage_policy, "can't be blank") if respond_to?(:usage_policy) && usage_policy.blank?

    errors.add(:lookup_digest, "can't be blank") if respond_to?(:lookup_digest) && lookup_digest.blank?
    errors.add(:safe_prefix, "can't be blank") if respond_to?(:safe_prefix) && safe_prefix.blank?
  end
end
