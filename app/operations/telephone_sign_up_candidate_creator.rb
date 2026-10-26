# frozen_string_literal: true

class TelephoneSignUpCandidateCreator
  class << self
    public

    def call(telephone:)
      raise ArgumentError, "Telephone signup requires a new candidate" unless telephone.new_record?

      case telephone
      when ClientTelephone
        if telephone.user_id || telephone.user
          raise ArgumentError, "Telephone signup cannot reuse an existing owner"
        end

        telephone_model = ClientTelephone
      when VisitorTelephone
        if telephone.visitor_id || telephone.visitor
          raise ArgumentError, "Telephone signup cannot reuse an existing owner"
        end

        telephone_model = VisitorTelephone
      else raise ArgumentError, "unsupported Telephone signup candidate"
      end

      if telephone.number_digest.blank?
        telephone_model.transaction { create_candidate(telephone) }
      else
        SignUpEmailPendingGuard.with_lock(number_digest: telephone.number_digest, model_class: telephone_model) do
          # D-135: a number still held by an unfinished registration waits for its cleanup.
          if SignUpContactHoldQuery.call(contact: telephone)
            next TelephoneSignUpCandidateResult.new(status: :contact_held, telephone:, session_payload: nil)
          end

          create_candidate(telephone)
        end
      end
    end

    private

    def create_candidate(telephone)
      case telephone
      when ClientTelephone
        telephone.user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, security_mode_id: ClientSecurityMode::NORMAL)
        telephone.user_telephone_status_id = ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
      when VisitorTelephone
        telephone.visitor = Visitor.create!(
          status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP,
          security_mode_id: VisitorSecurityMode::NORMAL, visibility_id: VisitorVisibility::VISITOR,
        )
        telephone.visitor_telephone_status_id = VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
      else raise ArgumentError, "unsupported Telephone signup candidate"
      end
      telephone.save!
      TelephoneSignUpCandidateResult.new(
        status: :created, telephone: telephone,
        session_payload: {
          public_id: telephone.public_id,
          confirm_policy: ActiveModel::Type::Boolean.new.cast(telephone.confirm_policy),
          confirm_using_mfa: ActiveModel::Type::Boolean.new.cast(telephone.confirm_using_mfa),
        },
      )
    end
  end
end
