# typed: false
# frozen_string_literal: true

# Creates the pending visitor telephone signup state after HTTP validation has passed.
class SignComUpTelephoneSignupCreator
  # Outcome consumed by the surface controller.
  Result = Data.define(:status, :telephone, :session_payload)

  def self.call(telephone:)
    new(telephone: telephone).call
  end

  def initialize(telephone:)
    @telephone = telephone
    @result = nil
  end

  def call
    # Effective binding uniqueness is decided at finalization, not at candidate creation.
    if @telephone.number_digest.blank?
      VisitorTelephone.transaction do
        create_pending_telephone
      end
    else
      SignUpEmailPendingGuard.with_lock(
        number_digest: @telephone.number_digest,
        model_class: VisitorTelephone,
      ) do
        create_pending_telephone
      end
    end

    @result
  end

  private

  def create_pending_telephone
    pending_visitor =
      Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    @telephone.visitor = pending_visitor
    @telephone.visitor_telephone_status_id = VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP

    SignTelephoneOtpDelivery.assign(@telephone)
    @telephone.save!

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
