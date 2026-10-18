# typed: false
# frozen_string_literal: true

# Opaque WebAuthn user handle for a passkey-owning actor. Generated once at
# create and never rotated: authenticators associate stored credentials with
# this value, so changing it would orphan every credential minted under the
# old handle. It carries no PII and is independent per surface database.
module WebauthnUserHandleOwner
  extend ActiveSupport::Concern

  USER_HANDLE_RANDOM_BYTES = 32

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    before_validation :ensure_webauthn_user_handle, on: :create
    # before_save as well: saves with validate: false skip before_validation
    # but must still satisfy the NOT NULL constraint.
    before_save :ensure_webauthn_user_handle

    validates :webauthn_user_handle, presence: true, uniqueness: true
  end

  private

  def ensure_webauthn_user_handle
    self.webauthn_user_handle ||= SecureRandom.urlsafe_base64(WebauthnUserHandleOwner::USER_HANDLE_RANDOM_BYTES)
  end
end
