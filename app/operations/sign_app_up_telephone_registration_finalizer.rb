# typed: false
# frozen_string_literal: true

# Atomically finalizes a pending telephone sign-up.
#
# Until this runs the telephone stays UNVERIFIED_WITH_SIGN_UP, so an
# abandoned cycle (OTP passed but passkey never completed) is still
# collectable by the pending-signup cleanup and the phone number can be
# reused. The durable VERIFIED_WITH_SIGN_UP transition, client promotion,
# and account creation only happen here, in one transaction, after the
# required passkey exists.
#
# See adr/sign-up-authentication-handoff-and-social-rt.md (telephone
# finalization is durable only after required Sign Up setup succeeds).
class SignAppUpTelephoneRegistrationFinalizer
  Result = Data.define(:user)

  # Raised when finalization is attempted before the required passkey
  # exists. This is a guard, not an expected path.
  class PasskeyMissingError < StandardError; end

  def self.call(telephone:, actor_context:, operation_ref:)
    new(telephone: telephone, actor_context: actor_context, operation_ref: operation_ref).call
  end

  def initialize(telephone:, actor_context:, operation_ref:)
    @telephone = telephone
    @actor_context = actor_context
    @operation_ref = operation_ref
  end

  def call
    user = nil

    ClientTelephone.transaction do
      user = Client.lock.find(@telephone.user_id)
      raise ActiveRecord::RecordNotSaved, "Contact owner is unavailable" unless user.active?

      telephone = ClientTelephone.lock.find(@telephone.id)
      raise ArgumentError, "telephone sign-up owner mismatch" unless telephone.user_id == user.id

      unless user.client_passkeys.active.exists?
        raise PasskeyMissingError, "telephone sign-up requires an active passkey"
      end

      telephone.confirm_policy = "1"
      telephone.confirm_using_mfa = "1"
      telephone.clear_otp
      telephone.user_telephone_status_id = ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP
      telephone.binding_finalized_at = ClientTelephone.database_now
      telephone.save!

      if user.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
        user.update!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      end
      ContactBindingAuditRecorder.call!(
        actor_context: @actor_context, actor: user, contact: telephone,
        operation_ref: @operation_ref, event_name: "finalized",
      )
    end

    Result.new(user: user)
  end
end
