# typed: false
# frozen_string_literal: true

module StepUpAvailableMethods
  module_function

  def call(subject, ticket: nil)
    return [] unless subject
    return [] if ticket&.attempt_count.to_i >= 5

    methods = StepUpConfiguredMethodsQuery.call(subject)
    return methods unless methods.include?(:email_otp)

    subject.class.connection_class_for_self.connected_to(role: :writing) do
      now = subject.class.database_now
      credentials =
        case subject
        when Client
          subject.client_emails.effective_binding.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
        when Visitor
          subject.visitor_emails.effective_binding.where(
            visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES,
          )
        else
          raise ArgumentError, "Email OTP is unavailable for this actor type"
        end
      available = credentials.where("discard_at > ?", now)
        .exists?(["step_up_otp_locked_until IS NULL OR step_up_otp_locked_until <= ?", now])
      available ? methods : methods - [:email_otp]
    end
  end
end
