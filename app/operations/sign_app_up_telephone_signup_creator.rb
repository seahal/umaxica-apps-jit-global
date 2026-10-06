# typed: false
# frozen_string_literal: true

# Creates the pending client telephone signup state after HTTP validation has passed.
class SignAppUpTelephoneSignupCreator
  # Outcome consumed by the surface controller.
  Result = Data.define(:status, :telephone, :session_payload)

  def self.call(telephone:, pending_public_id:)
    new(
      telephone: telephone,
      pending_public_id: pending_public_id,
    ).call
  end

  def initialize(telephone:, pending_public_id:)
    @telephone = telephone
    @pending_public_id = pending_public_id
    @result = nil
  end

  def call
    # Serialize per-number to prevent two concurrent sessions from
    # both passing the existence check and racing the unique index.
    if @telephone.number_digest.blank?
      ClientTelephone.transaction do
        perform_create_under_lock
      end
    else
      SignUpEmailPendingGuard.with_lock(
        number_digest: @telephone.number_digest,
        model_class: ClientTelephone,
      ) do
        perform_create_under_lock
      end
    end

    @result
  end

  private

  def perform_create_under_lock
    cleanup_pending_signup

    create_pending_telephone
  end

  def cleanup_pending_signup
    return if @pending_public_id.blank?

    pending_telephone = ClientTelephone.find_by(public_id: @pending_public_id)
    return unless pending_telephone

    pending_user = pending_telephone.user
    pending_telephone.destroy!
    pending_user.destroy! if pending_user&.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
  end

  def create_pending_telephone
    pending_user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    @telephone.user = pending_user
    @telephone.user_telephone_status_id = ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP

    otp_code = SignTelephoneOtpDelivery.assign(@telephone)
    @telephone.save!
    OtpAdapter.for(surface: :app, channel: :telephone).deliver(
      record: @telephone,
      otp_code: otp_code,
    )

    @result = Result.new(
      status: :created,
      telephone: @telephone,
      session_payload: session_payload,
    )
  end

  def session_payload
    {
      public_id: @telephone.public_id,
      confirm_policy: boolean_value(@telephone.confirm_policy),
      confirm_using_mfa: boolean_value(@telephone.confirm_using_mfa),
      expires_at: @telephone.otp_expires_at.to_i,
    }
  end

  def boolean_value(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
