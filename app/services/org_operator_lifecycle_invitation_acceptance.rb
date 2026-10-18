# typed: false
# frozen_string_literal: true

class OrgOperatorLifecycleInvitationAcceptance
  OrgOperatorLifecycleResult =
    Data.define(:success, :invitation, :operator, :email, :error) do
      def success? = !!success
    end

  def self.call(invitation_code:)
    new(invitation_code: invitation_code).call
  end

  def initialize(invitation_code:)
    @invitation_code = invitation_code.to_s.downcase.strip
  end

  def call
    invitation = validate_invitation
    operator = nil
    email = nil
    failure_result = nil

    OrganizationInvitation.transaction do
      invitation.lock!
      if invitation.consumed?
        failure_result = failure(invitation: invitation, error: "Invitation has already been used")
      elsif invitation.expired?
        failure_result = failure(invitation: invitation, error: "Invitation has expired")
      else
        operator, email = create_operator_identity!(invitation)
        invitation.consume!
      end
    end

    return failure_result if failure_result

    OrgOperatorLifecycleResult.new(success: true, invitation: invitation, operator: operator, email: email, error: nil)
  rescue OrgRegistrationPolicy::InvitationRequiredError,
         OrgRegistrationPolicy::InvalidInvitationError,
         OrgRegistrationPolicy::InvitationExpiredError,
         OrgRegistrationPolicy::InvitationConsumedError => e
    failure(error: e.message)
  rescue ActiveRecord::RecordInvalid => e
    failure(invitation: invitation, error: e.record.errors.full_messages.to_sentence)
  rescue ActiveRecord::RecordNotUnique
    failure(invitation: invitation, error: "Invitation email is already registered")
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "org.operator_lifecycle.invitation_acceptance.failed",
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
    failure(invitation: invitation, error: e.message)
  end

  private

  attr_reader :invitation_code

  def validate_invitation
    OrgRegistrationPolicy.validate!(invitation_code: invitation_code)
  end

  def create_operator_identity!(invitation)
    operator = nil
    email = nil

    OrgPrincipalRecord.transaction do
      operator = Operator.create!(
        status_id: OperatorStatus::ACTIVE,
        visibility_id: OperatorVisibility::STAFF,
      )
      email = operator.operator_emails.create!(
        raw_address: invitation.email,
        confirm_policy: true,
        staff_email_status_id: OperatorEmailStatus::VERIFIED,
        undeletable: true,
      )
    end

    # The OrgPrincipalRecord transaction above is already committed by
    # the time rp_account creation runs (different DB connection). If
    # the rp_account write fails, the outer OrganizationInvitation
    # transaction will roll back without consuming the invitation, but
    # the operator/email rows we just committed would survive as
    # orphans and block subsequent retries via the email UNIQUE index.
    # Run an explicit compensating delete so the invitation stays in a
    # clean state for retry.
    begin
      create_operator_account!(operator)
      IdentityGraphProvisioner.call!(surface: :org, principal: operator)
    rescue StandardError
      compensate_operator_creation!(operator)
      raise
    end

    [operator, email]
  end

  def create_operator_account!(operator)
    OrgRpRecord.transaction do
      OperatorAccount.create!(staff_id: operator.id)
    end
  end

  def compensate_operator_creation!(operator)
    return unless operator&.persisted?

    OrgPrincipalRecord.transaction do
      dependent_associations =
        Operator.reflect_on_all_associations.filter_map do |reflection|
          reflection.name if reflection.options[:dependent]
        end
      operator_for_destruction = Operator.includes(*dependent_associations).find(operator.id)
      operator_for_destruction.destroy!
    end
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "org.operator_lifecycle.invitation_acceptance.compensation_failed",
        operator_id: operator&.id,
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
    # Best-effort: re-raise the original rp_account failure even if
    # compensation itself fails. The orphan is preferable to swallowing
    # the underlying error.
  end

  def failure(invitation: nil, error:)
    OrgOperatorLifecycleResult.new(success: false, invitation: invitation, operator: nil, email: nil, error: error)
  end
end
