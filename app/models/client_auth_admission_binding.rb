# typed: false
# frozen_string_literal: true

class ClientAuthAdmissionBinding < OpBaseAppRecord
  include AuthAdmissionBinding

  belongs_to :sign_in_flow, class_name: "ClientSignInFlow", optional: true
  belongs_to :authorization_transaction, class_name: "ClientOidcAuthorizationTransaction", optional: true
  belongs_to :step_up_ceremony_transaction, class_name: "ClientStepUpCeremonyTransaction", optional: true
  belongs_to :base_token, class_name: "ClientToken", optional: true
  belongs_to :auth_ceremony_session, class_name: "ClientAuthCeremonySession", optional: true
  belongs_to :admitted_auth_ceremony_session, class_name: "ClientAuthCeremonySession", optional: true

  validates :entry_ref, presence: true, uniqueness: true
  validates :purpose, presence: true
  validates :base_browser_digest, presence: true, length: { is: 64 }
  validates :expires_at, :created_at, :updated_at, presence: true
  validate :validate_parent_shape
  validate :validate_purpose_parent
  validate :validate_base_token_requirement
  validate :validate_auth_proof_pair
  validate :validate_redemption_pair
  validate :validate_terminal_exclusivity
  before_update :reject_immutable_fact_changes

  class << self
    public

    def auth_admission_surface_name = "app"

    def auth_admission_base_token_class = ClientToken

    def auth_admission_session_class = ClientAuthCeremonySession

    def connection_owner = OpBaseAppRecord
  end
end
