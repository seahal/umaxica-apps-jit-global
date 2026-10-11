# typed: false
# frozen_string_literal: true

class RecoveryPasscodeTopUp
  TARGET_ACTIVE_RECOVERY_PASSCODES = 10

  Result = Struct.new(
    :new_credentials,
    :raw_values,
    :issued_count,
    :active_usable_count_before,
    :active_usable_count_after,
    :target_count,
    keyword_init: true,
  )

  def self.call(actor:, credential_class:, target_count: TARGET_ACTIVE_RECOVERY_PASSCODES, now: Time.current)
    new(actor: actor, credential_class: credential_class, target_count: target_count, now: now).call
  end

  def initialize(actor:, credential_class:, target_count:, now:)
    @actor = actor
    @credential_class = credential_class
    @target_count = target_count.to_i
    @now = now
  end

  def call
    return empty_result(active_usable_count_before: 0) unless supported_recovery_passcode_kind?

    active_usable_count_before = current_active_usable_count
    shortfall = @target_count - active_usable_count_before
    issue_count = [shortfall, available_headroom].min
    return empty_result(active_usable_count_before:) if issue_count <= 0

    preload_recovery_identity_associations!

    new_credentials = []
    raw_values = []
    starting_secret_count = total_secret_count
    recovery_passcode_legacy_attrs = recovery_passcode_legacy_attributes

    issue_count.times do |index|
      issued = issue_recovery_passcode!(
        name: "Recovery #{starting_secret_count + index + 1}",
        legacy_attributes: recovery_passcode_legacy_attrs,
      )
      new_credentials << issued.secret_credential
      raw_values << issued.raw_secret_credential
    end

    Result.new(
      new_credentials: new_credentials,
      raw_values: raw_values,
      issued_count: issue_count,
      active_usable_count_before: active_usable_count_before,
      active_usable_count_after: active_usable_count_before + issue_count,
      target_count: @target_count,
    )
  end

  private

  attr_reader :actor, :credential_class, :now

  def empty_result(active_usable_count_before:)
    Result.new(
      new_credentials: [],
      raw_values: [],
      issued_count: 0,
      active_usable_count_before: active_usable_count_before,
      active_usable_count_after: active_usable_count_before,
      target_count: @target_count,
    )
  end

  def supported_recovery_passcode_kind?
    recovery_kind_id.present?
  end

  def recovery_kind_id
    credential_class.const_get(:RECOVERY)
  rescue NameError
    nil
  end

  def current_active_usable_count
    SignRecoveryPasscodeRequirement.usable_unused_count(
      actor: actor,
      credential_class: credential_class,
      now: now,
    )
  end

  def available_headroom
    limit = max_secret_count_limit
    return Float::INFINITY if limit.blank?

    [limit - total_secret_count, 0].max
  end

  def max_secret_count_limit
    case credential_class.name
    when "ClientSecretCredential"
      credential_class::MAX_SECRETS_PER_USER
    when "VisitorSecretCredential"
      credential_class::MAX_SECRETS_PER_VISITOR
    when "OperatorSecretCredential"
      credential_class::MAX_SECRETS_PER_STAFF
    end
  rescue NameError
    nil
  end

  def total_secret_count
    secret_credential_relation.count
  end

  def preload_recovery_identity_associations!
    actor.client_emails.load if actor.respond_to?(:client_emails)
    actor.client_telephones.load if actor.respond_to?(:client_telephones)
    actor.visitor_emails.load if actor.respond_to?(:visitor_emails)
    actor.visitor_telephones.load if actor.respond_to?(:visitor_telephones)
    actor.staff_emails.load if actor.respond_to?(:staff_emails)
    actor.staff_telephones.load if actor.respond_to?(:staff_telephones)
  end

  def secret_credential_relation
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

  def issue_recovery_passcode!(name:, legacy_attributes:)
    credential_collection = secret_credential_relation
    credential_class.transaction do
      SignSecretIssue.call(
        credential_collection: credential_collection,
        secret_credential_class: credential_class,
        name: name,
        secret_kind: :recovery,
        usage_policy: :single_use,
        legacy_attributes: legacy_attributes,
        issued_at: now,
      )
    end
  end

  def recovery_passcode_legacy_attributes
    attrs = {}
    kind_association = recovery_kind_association
    kind_record = recovery_kind_record
    attrs[kind_association] = kind_record if kind_association.present? && kind_record.present?

    status_association = recovery_status_association
    status_record = active_status_record
    attrs[status_association] = status_record if status_association.present? && status_record.present?
    attrs[:uses_remaining] = 1 if credential_class.column_names.include?("uses_remaining")
    attrs
  end

  def recovery_kind_association
    case credential_class.name
    when "ClientSecretCredential"
      :user_secret_credential_kind
    when "VisitorSecretCredential"
      :visitor_secret_credential_kind
    when "OperatorSecretCredential"
      :staff_secret_credential_kind
    end
  end

  def recovery_kind_record
    @recovery_kind_record ||=
      begin
        kind_id = recovery_kind_id
        nil if kind_id.nil?

        credential_class.reflect_on_association(recovery_kind_association)&.klass&.find(kind_id)
      end
  end

  def recovery_status_association
    credential_class.reflect_on_all_associations(:belongs_to).find do |association|
      association.name == :user_secret_credential_status ||
        association.name == :visitor_secret_credential_status ||
        association.name == :staff_secret_credential_status
    end&.name
  end

  def active_status_record
    @active_status_record ||=
      begin
        status_class = credential_class.identity_secret_credential_status_class
        status_id = status_class.const_get(:ACTIVE)
        status_class.find(status_id)
      rescue NameError
        nil
      end
  end
end
