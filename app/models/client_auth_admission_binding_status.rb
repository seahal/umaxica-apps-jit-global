# frozen_string_literal: true
# typed: false

class ClientAuthAdmissionBindingStatus < OpBaseAppRecord
  include ReferenceRecord

  ISSUED = AuthAdmissionBinding::ISSUED_STATUS_ID
  ATTACHED = AuthAdmissionBinding::ATTACHED_STATUS_ID
  BASE_CONFIRMED = AuthAdmissionBinding::BASE_CONFIRMED_STATUS_ID
  REDEEMED = AuthAdmissionBinding::REDEEMED_STATUS_ID
  RETIRED = AuthAdmissionBinding::RETIRED_STATUS_ID
  SWITCHED = AuthAdmissionBinding::SWITCHED_STATUS_ID
  DEFAULTS = [ISSUED, ATTACHED, BASE_CONFIRMED, REDEEMED, RETIRED, SWITCHED].freeze

  has_many :client_auth_admission_bindings,
           class_name: "ClientAuthAdmissionBinding",
           foreign_key: :status_id,
           inverse_of: :status,
           dependent: :restrict_with_error
end
