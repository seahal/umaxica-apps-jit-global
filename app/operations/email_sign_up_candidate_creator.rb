# frozen_string_literal: true

class EmailSignUpCandidateCreator
  class << self
    public

    def call(email:)
      raise ArgumentError, "Email signup requires a new candidate" unless email.new_record?

      email.class.transaction do
        owner =
          case email
          when ClientEmail
            raise ArgumentError, "Email signup cannot reuse an existing owner" if email.user_id || email.user

            email.user_email_status_id = ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
            email.user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, security_mode_id: ClientSecurityMode::NORMAL)
          else raise ArgumentError, "unsupported Email signup candidate realm"
          end
        email.save!
        owner
      end
    end
  end
end
