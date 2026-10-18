# typed: false
# frozen_string_literal: true

class AuthenticationCredentialInventory
  Result =
    Struct.new(
      :actor,
      :excluding,
      :sign_in_methods,
      :step_up_methods,
      :uv_step_up_methods,
      :contact_identifiers,
      :phishing_resistant_methods,
      keyword_init: true,
    ) do
      # These names describe the capability that remains after a proposed mutation. They are
      # deliberately independent of legacy assurance labels and of database row counts.
      def usable_sign_in_capabilities = sign_in_methods

      def usable_step_up_capabilities = uv_step_up_methods

      def has_usable_sign_in_capability? = usable_sign_in_capabilities.any?

      def has_usable_step_up_capability? = usable_step_up_capabilities.any?

      def contact_identifier_count = contact_identifiers.count
    end

  def self.call(actor, excluding: nil, reload: false)
    new(actor, excluding: excluding, reload: reload).call
  end

  def initialize(actor, excluding: nil, reload: false)
    @actor = actor
    @excluding = excluding
    @reload = reload
  end

  def call
    return empty_result unless actor

    writer =
      case actor
      when Client then AppZenithRecord
      when Visitor then ComZenithRecord
      when Operator then OrgZenithRecord
      else raise ArgumentError, "credential inventory actor unavailable"
      end
    writer.connected_to(role: :writing) { read_inventory }
  end

  private

  attr_reader :actor, :excluding, :reload, :decision_time

  # One writer-clock snapshot classifies every retained credential in this decision.
  def read_inventory
    @decision_time = actor.class.database_now
    actor.reload if reload && actor.persisted?

    Result.new(
      actor: actor,
      excluding: excluding,
      sign_in_methods: sign_in_methods,
      step_up_methods: normal_step_up_methods,
      uv_step_up_methods: uv_step_up_methods,
      contact_identifiers: contact_identifiers,
      phishing_resistant_methods: phishing_resistant_methods,
    )
  end

  def empty_result
    Result.new(
      actor: actor,
      excluding: excluding,
      sign_in_methods: [],
      step_up_methods: [],
      uv_step_up_methods: [],
      contact_identifiers: [],
      phishing_resistant_methods: [],
    )
  end

  def sign_in_methods
    methods = []
    methods.concat(client_social_login_methods)
    methods << :email_otp if contact_email_count.positive?
    methods << :passkey if active_passkey_count.positive?
    methods << :secret if active_client_secret_count.positive? && contact_identifier_count.positive?
    methods
  end

  def contact_identifier_count
    contact_email_count + contact_telephone_count
  end

  def active_client_secret_count
    return 0 unless actor.is_a?(Client)

    AppZenithRecord.connected_to(role: :writing) do
      scope = ClientSecretCredential.available_at(decision_time).where(client_id: actor.id)
      scope = scope.where.not(id: excluding.id) if excluding.is_a?(ClientSecretCredential)
      scope.count
    end
  end

  def normal_step_up_methods
    methods = []
    methods << :email_otp if (actor.is_a?(Client) || actor.is_a?(Visitor)) && contact_email_count.positive?
    methods << :passkey if active_passkey_count.positive?
    methods << :totp if active_totp_count.positive?
    methods
  end

  # Removal guards must not treat legacy passkeys with unknown UV history as a
  # guaranteed compatible fallback. They remain selectable so a successful UV
  # assertion can establish the fact, but cannot protect removal of another method.
  def uv_step_up_methods
    methods = []
    methods << :email_otp if unlocked_step_up_email_count.positive?
    methods << :passkey if uv_verified_passkey_count.positive?
    methods << :totp if active_totp_count.positive?
    methods
  end

  def unlocked_step_up_email_count
    scope =
      case actor
      when Client
        actor.client_emails.effective_binding.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
      when Visitor
        actor.visitor_emails.effective_binding.where(visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES)
      when Operator
        return 0
      else
        raise ArgumentError, "credential inventory actor unavailable"
      end
    scope = scope.where.not(id: excluding.id) if excluding.is_a?(ClientEmail) || excluding.is_a?(VisitorEmail)
    scope.where("discard_at > ?", decision_time)
      .where("step_up_otp_locked_until IS NULL OR step_up_otp_locked_until <= ?", decision_time).count
  end

  def contact_identifiers
    methods = []
    methods << :email if contact_email_count.positive?
    methods << :telephone if contact_telephone_count.positive?
    methods
  end

  def phishing_resistant_methods
    normal_step_up_methods & [:passkey]
  end

  def client_social_login_methods
    common_client_social_login_methods
  end

  def common_client_social_login_methods
    return [] unless actor.respond_to?(:client_external_identities)

    scope = actor.client_external_identities.effective_binding.where(state: "active")
    scope = scope.where.not(id: excluding.id) if excluding.is_a?(ClientExternalIdentity)
    scope.pluck(:provider).map(&:to_sym)
  end

  def contact_email_count
    if actor.respond_to?(:client_emails)
      return count_scope(
        actor.client_emails.effective_binding.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
          .where("discard_at > ?", decision_time),
        "ClientEmail",
      )
    end

    if actor.respond_to?(:visitor_emails)
      return count_scope(
        actor.visitor_emails.effective_binding.where(visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES)
          .where("discard_at > ?", decision_time),
        "VisitorEmail",
      )
    end

    if actor.respond_to?(:staff_emails)
      return count_scope(
        actor.staff_emails.where(
          staff_identity_email_status_id: [
            OperatorEmailStatus::ACTIVE,
            OperatorEmailStatus::VERIFIED,
          ],
        ),
        "OperatorEmail",
      )
    end

    0
  end

  def contact_telephone_count
    if actor.respond_to?(:client_telephones)
      return count_scope(
        actor.client_telephones.effective_binding.where(
          user_identity_telephone_status_id: AuthMethodGuard::VERIFIED_TELEPHONE_STATUSES,
        ).where("discard_at > ?", decision_time),
        "ClientTelephone",
      )
    end

    if actor.respond_to?(:visitor_telephones)
      return count_scope(
        actor.visitor_telephones.effective_binding.where(
          visitor_telephone_status_id: AuthMethodGuard::VISITOR_VERIFIED_TELEPHONE_STATUSES,
        ).where("discard_at > ?", decision_time),
        "VisitorTelephone",
      )
    end

    if actor.respond_to?(:staff_telephones)
      return count_scope(
        actor.staff_telephones.where(
          staff_identity_telephone_status_id: [
            OperatorTelephoneStatus::ACTIVE,
            OperatorTelephoneStatus::VERIFIED,
          ],
        ),
        "OperatorTelephone",
      )
    end

    0
  end

  def active_passkey_count
    if actor.respond_to?(:client_passkeys)
      return count_scope(
        actor.client_passkeys.where(status_id: ClientPasskeyStatus::ACTIVE).where(
          "discard_at > ?",
          decision_time,
        ), "ClientPasskey",
      )
    end

    if actor.respond_to?(:visitor_passkeys)
      return count_scope(
        actor.visitor_passkeys.where(status_id: VisitorPasskeyStatus::ACTIVE).where(
          "discard_at > ?",
          decision_time,
        ), "VisitorPasskey",
      )
    end

    if actor.respond_to?(:staff_passkeys)
      return count_scope(actor.staff_passkeys.where(status_id: OperatorPasskeyStatus::ACTIVE), "OperatorPasskey")
    end

    0
  end

  def uv_verified_passkey_count
    scope = active_passkeys_scope
    return 0 unless scope

    count_scope(scope.where.not(uv_verified_at: nil), scope.klass.name)
  end

  def active_passkeys_scope
    return actor.client_passkeys.where(status_id: ClientPasskeyStatus::ACTIVE).where(
      "discard_at > ?",
      decision_time,
    ) if actor.respond_to?(:client_passkeys)
    return actor.visitor_passkeys.where(status_id: VisitorPasskeyStatus::ACTIVE).where(
      "discard_at > ?",
      decision_time,
    ) if actor.respond_to?(:visitor_passkeys)
    return actor.staff_passkeys.where(status_id: OperatorPasskeyStatus::ACTIVE) if actor.respond_to?(:staff_passkeys)

    nil
  end

  def active_totp_count
    return 0 unless actor.respond_to?(:client_totp_credentials)

    count_scope(
      actor.client_totp_credentials.where(
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      ),
      "ClientTotpCredential",
    )
  end

  def count_scope(scope, class_name)
    scope = scope.where.not(id: excluding.id) if excluding_record?(class_name)
    scope.count
  end

  def excluding_record?(class_name)
    excluding.present? && excluding.respond_to?(:id) && excluding.class.name == class_name
  end
end
