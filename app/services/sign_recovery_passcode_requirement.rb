# typed: false
# frozen_string_literal: true

class SignRecoveryPasscodeRequirement
  MINIMUM_USABLE_UNUSED_RECOVERY_PASSCODES = 2

  def self.usable_unused_count(actor:, credential_class:, now: Time.current)
    new(actor: actor, credential_class: credential_class, now: now).usable_unused_count
  end

  def initialize(actor:, credential_class:, now: Time.current)
    @actor = actor
    @credential_class = credential_class
    @now = now
  end

  def usable_unused_count
    usable_unused_relation.count
  end

  private

  attr_reader :actor, :credential_class, :now

  def usable_unused_relation
    relation = actor_secret_credentials
    relation = relation.where(status_column => credential_class::SIGN_IN_ALLOWED_STATUS_IDS)
    return relation.none unless credential_class.const_defined?(:RECOVERY)

    recovery_kind_id = credential_class.const_get(:RECOVERY)

    relation = relation.where(kind_column => recovery_kind_id)
    relation = relation.where(last_used_at: nil)
    relation = relation.where(
      "discard_at IS NULL OR discard_at > ?",
      now,
    ) if credential_class.column_names.include?("discard_at")
    relation = relation.where(
      "purge_eligible_at IS NULL OR purge_eligible_at > ?",
      now,
    ) if credential_class.column_names.include?("purge_eligible_at")
    relation = relation.where("uses_remaining > 0") if credential_class.column_names.include?("uses_remaining")
    relation
  end

  def actor_secret_credentials
    case credential_class.name
    when "ClientSecretCredential"
      actor.client_secret_credentials
    when "VisitorSecretCredential"
      actor.visitor_secret_credentials
    when "OperatorSecretCredential"
      actor.staff_secret_credentials
    else
      raise ArgumentError, "unsupported recovery passcode credential class: #{credential_class.name}"
    end
  end

  def status_column
    credential_class.identity_secret_credential_status_id_column
  end

  def kind_column
    case credential_class.name
    when "ClientSecretCredential"
      :user_secret_kind_id
    when "VisitorSecretCredential"
      :visitor_secret_credential_kind_id
    when "OperatorSecretCredential"
      :staff_secret_kind_id
    end
  end
end
