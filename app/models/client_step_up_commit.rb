# frozen_string_literal: true

class ClientStepUpCommit < OpBaseAppRecord
  attr_readonly :grant_id, :root_token_id, :context_ref, :verified_method, :committed_at

  belongs_to :grant, class_name: "OpAppGrant"
  belongs_to :root_token, class_name: "ClientToken"

  validates :context_ref, :committed_at, presence: true
  validates :context_ref, length: { maximum: 21 }
  validates :verified_method, inclusion: { in: %w(passkey totp email_otp) }
  validates :verified_method, length: { maximum: 16 }
end
