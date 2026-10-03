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

  def self.call(telephone:)
    new(telephone: telephone).call
  end

  def initialize(telephone:)
    @telephone = telephone
  end

  def call
    user = nil

    ClientTelephone.transaction do
      telephone = ClientTelephone.lock.find(@telephone.id)
      user = Client.lock.find(telephone.user_id)

      unless user.client_passkeys.active.exists?
        raise PasskeyMissingError, "telephone sign-up requires an active passkey"
      end

      telephone.confirm_policy = "1"
      telephone.confirm_using_mfa = "1"
      telephone.clear_otp
      telephone.user_telephone_status_id = ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP
      telephone.save!

      if user.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
        user.update!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      end
    end

    # Chronicle write must happen AFTER the transaction commits.
    # If the transaction above rolls back, this line is never
    # reached and we cannot leak an orphan SIGNED_UP_WITH_TELEPHONE
    # row that points to a user that does not exist. See S-8.
    write_signup_audit!(user)
    Result.new(user: user)
  end

  private

  def write_signup_audit!(user)
    event_id = ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE

    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicleEvent.find_or_create_by!(id: event_id)
      ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
    end

    ClientChronicle.create!(
      actor_type: "Client",
      actor_id: user.id,
      event_id: event_id,
      subject_id: user.id.to_s,
      subject_type: "Client",
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error(
      JitLogEvent.format(
        "sign.signup.telephone.audit_save_failed",
        user_id: user&.id,
        event_id: event_id,
        errors: e.record.errors.full_messages,
        exception: e,
      ),
    )
    raise
  end
end
