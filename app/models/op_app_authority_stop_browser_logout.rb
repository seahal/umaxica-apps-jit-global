# typed: false
# frozen_string_literal: true

# The browser-bound child of a browser_logout / rp_initiated_logout stop, with its one-time receipt.
class OpAppAuthorityStopBrowserLogout < OpBaseAppRecord
  belongs_to :stop, class_name: "OpAppAuthorityStop", inverse_of: :browser_logout

  validates :browser_binding_digest, :receipt_nonce_digest, :receipt_expires_at, presence: true
  validates :receipt_consumed, inclusion: { in: [true, false] }
end
