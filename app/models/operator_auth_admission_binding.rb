# typed: false
# frozen_string_literal: true

class OperatorAuthAdmissionBinding < OpBaseOrgRecord
  include AuthAdmissionBinding

  belongs_to :authorization_transaction, class_name: "OperatorOidcAuthorizationTransaction", optional: true
  belongs_to :step_up_ceremony_transaction, class_name: "OperatorStepUpCeremonyTransaction", optional: true
  belongs_to :base_token, class_name: "OperatorToken", optional: true
  belongs_to :auth_ceremony_session, class_name: "OperatorAuthCeremonySession", optional: true
  belongs_to :admitted_auth_ceremony_session, class_name: "OperatorAuthCeremonySession", optional: true

  validates :entry_ref, presence: true, uniqueness: true
  validates :purpose, presence: true
  validates :base_browser_digest, presence: true, length: { is: 64 }
  validates :expires_at, :curfew_at, :entry_intent, :created_at, :updated_at, presence: true
  validate :validate_entry_intent
  validate :validate_parent_shape
  validate :validate_purpose_parent
  validate :validate_base_token_requirement
  validate :validate_auth_proof_pair
  validate :validate_redemption_pair
  validate :validate_terminal_exclusivity
  before_update :reject_immutable_fact_changes

  class << self
    public

    def auth_admission_surface_name = "org"

    def auth_admission_base_token_class = OperatorToken

    def auth_admission_session_class = OperatorAuthCeremonySession

    def connection_owner = OpBaseOrgRecord
  end
end
