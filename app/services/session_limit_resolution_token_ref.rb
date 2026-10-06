# typed: false
# frozen_string_literal: true

class SessionLimitResolutionTokenRef
  EXPIRES_IN = 15.minutes

  def self.issue(token)
    Rails.application.message_verifier(:session_limit_resolution_token_ref).generate(
      { pid: token.public_id },
      expires_in: EXPIRES_IN,
    )
  end

  def self.find_client_token(ref)
    data = Rails.application.message_verifier(:session_limit_resolution_token_ref).verify(ref.to_s)
    public_id = data[:pid] || data["pid"]
    return nil if public_id.blank?

    AppTicketRecord.connected_to(role: :writing) do
      ClientToken.find_by(public_id: public_id)
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.find_visitor_token(ref)
    data = Rails.application.message_verifier(:session_limit_resolution_token_ref).verify(ref.to_s)
    public_id = data[:pid] || data["pid"]
    return nil if public_id.blank?

    ComTicketRecord.connected_to(role: :writing) do
      VisitorToken.find_by(public_id: public_id)
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.find_operator_token(ref)
    data = Rails.application.message_verifier(:session_limit_resolution_token_ref).verify(ref.to_s)
    public_id = data[:pid] || data["pid"]
    return nil if public_id.blank?

    OrgTicketRecord.connected_to(role: :writing) do
      OperatorToken.find_by(public_id: public_id)
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end
end
