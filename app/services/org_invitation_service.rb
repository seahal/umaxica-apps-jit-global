# typed: false
# frozen_string_literal: true

class OrgInvitationService
  MIGRATION_REQUIRED_MESSAGE = "Organization invitations are unavailable pending Bureau migration"

  Result =
    Data.define(:success, :invitation, :code, :error) do
      def success? = !!success
    end

  def self.create(organization_id:, email:, invited_by:, role_id: 0)
    # Issuance stays closed until target Bureau, Unit and grant authority are explicit.
    Result.new(success: false, invitation: nil, code: nil, error: MIGRATION_REQUIRED_MESSAGE)
  end

  def self.validate(code:, email: nil)
    new.validate(code: code, email: email)
  end

  def self.consume(code:, email: nil)
    new.consume(code: code, email: email)
  end

  def validate(code:, email: nil)
    invitation = OrganizationInvitation.find_valid(code, email: email)

    if invitation
      Result.new(success: true, invitation: invitation, code: code, error: nil)
    else
      Result.new(success: false, invitation: nil, code: code, error: "Invalid or expired invitation code")
    end
  end

  def consume(code:, email: nil)
    invitation = OrganizationInvitation.find_valid(code, email: email)

    unless invitation
      return Result.new(success: false, invitation: nil, code: code, error: "Invalid or expired invitation code")
    end

    if invitation.consume!
      Result.new(success: true, invitation: invitation, code: code, error: nil)
    else
      Result.new(success: false, invitation: invitation, code: code, error: "Failed to consume invitation")
    end
  end
end
