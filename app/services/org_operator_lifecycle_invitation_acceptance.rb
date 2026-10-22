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
    invitation = OrgRegistrationPolicy.validate!(invitation_code: invitation_code)

    # A legacy organization reference cannot authorize membership in a Bureau.
    failure(invitation: invitation, error: OrgInvitationService::MIGRATION_REQUIRED_MESSAGE)
  rescue OrgRegistrationPolicy::InvitationRequiredError,
         OrgRegistrationPolicy::InvalidInvitationError,
         OrgRegistrationPolicy::InvitationExpiredError,
         OrgRegistrationPolicy::InvitationConsumedError => e
    failure(error: e.message)
  end

  private

  attr_reader :invitation_code

  def failure(invitation: nil, error:)
    OrgOperatorLifecycleResult.new(success: false, invitation: invitation, operator: nil, email: nil, error: error)
  end
end
