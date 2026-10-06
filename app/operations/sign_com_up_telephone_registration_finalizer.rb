# typed: false
# frozen_string_literal: true

# Atomically finalizes a pending telephone sign-up for the Com surface.
#
# Mirrors SignAppUpTelephoneRegistrationFinalizer, but operates
# on VisitorTelephone/Visitor instead of ClientTelephone/Client.
#
# Until this runs the telephone stays UNVERIFIED_WITH_SIGN_UP, so an
# abandoned cycle is still collectable by the pending-signup cleanup
# and the phone number can be reused. The durable
# VERIFIED_WITH_SIGN_UP transition and rp_account creation only happen
# here, in one transaction.
class SignComUpTelephoneRegistrationFinalizer
  Result = Data.define(:visitor)

  def self.call(telephone:)
    new(telephone: telephone).call
  end

  def initialize(telephone:)
    @telephone = telephone
  end

  def call
    visitor = nil

    VisitorTelephone.transaction do
      telephone = VisitorTelephone.lock.find(@telephone.id)
      visitor = Visitor.lock.find(telephone.visitor_id)

      telephone.confirm_policy = "1"
      telephone.confirm_using_mfa = "1"
      telephone.clear_otp
      telephone.visitor_telephone_status_id = VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP
      telephone.binding_finalized_at = VisitorTelephone.database_now
      telephone.save!
    end

    Result.new(visitor: visitor)
  end
end
