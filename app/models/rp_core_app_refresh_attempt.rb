# typed: false
# frozen_string_literal: true

class RpCoreAppRefreshAttempt < RpCoreAppRecord
  self.table_name = "rp_refresh_attempts"

  CELL = RpCellBinding.fetch("rp_core_app")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  include PublicId

  belongs_to :session, class_name: "RpCoreAppSession", inverse_of: :refresh_attempts

  validates :input_hmac, :expected_installed_generation, :expires_at, presence: true
  validates :expected_installed_generation, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
