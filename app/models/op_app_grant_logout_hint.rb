# typed: false
# frozen_string_literal: true

# WU-14 (D-33): the verified ID Token of one OpAppGrant, presented as the end-session id_token_hint.
class OpAppGrantLogoutHint < OpBaseAppRecord
  encrypts :id_token

  belongs_to :grant, class_name: "OpAppGrant", inverse_of: :logout_hint

  validates :id_token, presence: true
end
