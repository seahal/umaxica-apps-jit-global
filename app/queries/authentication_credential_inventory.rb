# typed: false
# frozen_string_literal: true

class AuthenticationCredentialInventory
  Result =
    Struct.new(
      :actor,
      :excluding,
      :aal1_methods,
      :aal2_methods,
      :aal3_methods,
      :step_up_methods,
      :uv_step_up_methods,
      :contact_identifiers,
      :phishing_resistant_methods,
      keyword_init: true,
    ) do
      alias_method :login_methods, :aal1_methods

      def aal1_method_count = aal1_methods.count

      def aal2_method_count = aal2_methods.count

      def aal3_method_count = aal3_methods.count

      def contact_identifier_count = contact_identifiers.count

      def login_method_count = aal1_method_count

      def step_up_method_count = step_up_methods.count

      def aal1_available? = aal1_method_count.positive?

      def aal2_available? = aal2_method_count.positive?

      def aal3_available? = aal3_method_count.positive?

      def contactable? = contact_identifier_count.positive?

      def login_available? = aal1_available?

      def step_up_available? = step_up_method_count.positive?

      def retains_aal1? = aal1_available?

      def retains_aal2? = aal2_available?

      def retains_aal3? = aal3_available?

      def retains_contactability? = contactable?

      def retains_login? = login_available?

      def retains_step_up? = step_up_available?

      def retains_uv_step_up? = uv_step_up_methods.any?

      def last_aal1_method? = aal1_method_count.zero?

      def last_aal2_method? = aal2_method_count.zero?

      def last_contact_identifier? = contact_identifier_count.zero?

      def last_login_method? = last_aal1_method?

      def last_step_up_method? = step_up_method_count.zero?

      def removable_aal1_credential? = !last_aal1_method?

      def removable_aal2_credential? = !last_aal2_method?

      def removable_contact_identifier? = !last_contact_identifier?

      def removable_login_credential? = removable_aal1_credential?

      def removable_step_up_credential? = !last_step_up_method?
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

    actor.reload if reload && actor.respond_to?(:persisted?) && actor.persisted?

    Result.new(
      actor: actor,
      excluding: excluding,
      aal1_methods: aal1_methods,
      aal2_methods: aal2_methods,
      aal3_methods: [],
      step_up_methods: normal_step_up_methods,
      uv_step_up_methods: uv_step_up_methods,
      contact_identifiers: contact_identifiers,
      phishing_resistant_methods: phishing_resistant_methods,
    )
  end

  private

  attr_reader :actor, :excluding, :reload

  def empty_result
    Result.new(
      actor: actor,
      excluding: excluding,
      aal1_methods: [],
      aal2_methods: [],
      aal3_methods: [],
      step_up_methods: [],
      uv_step_up_methods: [],
      contact_identifiers: [],
      phishing_resistant_methods: [],
    )
  end

  def aal1_methods
    methods = []
    methods.concat(client_social_login_methods)
    methods << :email_otp if aal1_email_count.positive?
    methods << :passkey if active_passkey_count.positive?
    methods << :secret_credential if sign_in_secret_credential_count.positive?
    methods
  end

  def aal2_methods
    []
  end

  def normal_step_up_methods
    methods = []
    methods << :email_otp if aal1_email_count.positive?
    methods << :passkey if active_passkey_count.positive?
    methods << :totp if active_totp_count.positive?
    methods
  end

  # Removal guards must not treat legacy passkeys with unknown UV history as a
  # guaranteed compatible fallback. They remain selectable so a successful UV
  # assertion can establish the fact, but cannot protect removal of another method.
  def uv_step_up_methods
    methods = []
    methods << :email_otp if aal1_email_count.positive?
    methods << :passkey if uv_verified_passkey_count.positive?
    methods << :totp if active_totp_count.positive?
    methods
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

    scope = actor.client_external_identities.where(state: "active")
    scope = scope.where.not(id: excluding.id) if excluding.is_a?(ClientExternalIdentity)
    scope.pluck(:provider).map(&:to_sym)
  end

  def aal1_email_count
    return contact_email_count if actor.respond_to?(:client_emails)
    return contact_email_count if actor.respond_to?(:visitor_emails)

    0
  end

  def contact_email_count
    if actor.respond_to?(:client_emails)
      return count_scope(
        actor.client_emails.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES),
        "ClientEmail",
      )
    end

    if actor.respond_to?(:visitor_emails)
      return count_scope(
        actor.visitor_emails.where(visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES),
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
        actor.client_telephones.where(
          user_identity_telephone_status_id: AuthMethodGuard::VERIFIED_TELEPHONE_STATUSES,
        ),
        "ClientTelephone",
      )
    end

    if actor.respond_to?(:visitor_telephones)
      return count_scope(
        actor.visitor_telephones.where(
          visitor_telephone_status_id: AuthMethodGuard::VISITOR_VERIFIED_TELEPHONE_STATUSES,
        ),
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
      return count_scope(actor.client_passkeys.where(status_id: ClientPasskeyStatus::ACTIVE), "ClientPasskey")
    end

    if actor.respond_to?(:visitor_passkeys)
      return count_scope(actor.visitor_passkeys.where(status_id: VisitorPasskeyStatus::ACTIVE), "VisitorPasskey")
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
    return actor.client_passkeys.where(status_id: ClientPasskeyStatus::ACTIVE) if actor.respond_to?(:client_passkeys)
    return actor.visitor_passkeys.where(status_id: VisitorPasskeyStatus::ACTIVE) if actor.respond_to?(:visitor_passkeys)
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

  def sign_in_secret_credential_count
    if actor.respond_to?(:client_secret_credentials)
      return count_scope(
        actor.client_secret_credentials.allowed_for_secret_credential_sign_in,
        "ClientSecretCredential",
      )
    end

    if actor.respond_to?(:visitor_secret_credentials)
      return count_scope(
        actor.visitor_secret_credentials.allowed_for_secret_credential_sign_in,
        "VisitorSecretCredential",
      )
    end

    if actor.respond_to?(:staff_secret_credentials)
      return count_scope(
        actor.staff_secret_credentials.allowed_for_secret_credential_sign_in,
        "OperatorSecretCredential",
      )
    end

    0
  end

  def count_scope(scope, class_name)
    scope = scope.where.not(id: excluding.id) if excluding_record?(class_name)
    scope.count
  end

  def excluding_record?(class_name)
    excluding.present? && excluding.respond_to?(:id) && excluding.class.name == class_name
  end
end
