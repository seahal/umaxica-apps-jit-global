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

  def self.call(telephone:, actor_context:, operation_ref:)
    new(telephone: telephone, actor_context: actor_context, operation_ref: operation_ref).call
  end

  def initialize(telephone:, actor_context:, operation_ref:)
    @telephone = telephone
    @actor_context = actor_context
    @operation_ref = operation_ref
  end

  def call
    visitor = nil

    VisitorTelephone.transaction do
      visitor = Visitor.lock.find(@telephone.visitor_id)
      raise ActiveRecord::RecordNotSaved, "Contact owner is unavailable" unless visitor.active?

      telephone = VisitorTelephone.lock.find(@telephone.id)
      raise ArgumentError, "telephone sign-up owner mismatch" unless telephone.visitor_id == visitor.id

      telephone.confirm_policy = "1"
      telephone.confirm_using_mfa = "1"
      telephone.clear_otp
      telephone.visitor_telephone_status_id = VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP
      telephone.binding_finalized_at = VisitorTelephone.database_now
      telephone.save!
      ContactBindingAuditRecorder.call!(
        actor_context: @actor_context, actor: visitor, contact: telephone,
        operation_ref: @operation_ref, event_name: "finalized",
      )
    end

    Result.new(visitor: visitor)
  end
end
