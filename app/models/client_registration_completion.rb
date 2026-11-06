# frozen_string_literal: true

# Historical source fact. Current account/credential status never substitutes for this receipt.
class ClientRegistrationCompletion < AppZenithRecord
  class Conflict < StandardError; end

  belongs_to :client, inverse_of: false
  belongs_to :completion_method, foreign_key: :method_id, class_name: "ClientRegistrationCompletionMethod",
                                 inverse_of: :completions
  validates :public_id, :sign_up_flow_ref, presence: true
  validates :public_id, :sign_up_flow_ref, length: { is: 21 }
  validates :completed_at, presence: true

  public

  def readonly?
    persisted?
  end

  def verify_flow!(flow)
    raise Conflict, "A durable APP signup flow is required" unless flow.is_a?(ClientSignUpFlow) && flow.persisted?

    contact_type = %w(google apple).include?(flow.entry_method) ? "social_identity" : flow.entry_method
    flow.association(:auth_admission_binding).scope.take!
    # Curfew gates the transition into FINALIZING; a source commit already authorized there can
    # land later, while the Sign-in handoff remains independently subject to the curfew.
    unless flow.is_a?(ClientSignUpFlow) && client_id == flow.principal_id &&
        sign_up_flow_ref == flow.public_id &&
        method_id == ClientRegistrationCompletionMethod::IDS.fetch(flow.entry_method) &&
        flow.pending_contact_type == contact_type && completed_at >= flow.issued_at &&
        completed_at < flow.expires_at
      raise Conflict, "Registration completion does not match its original flow"
    end

    self
  end
end
