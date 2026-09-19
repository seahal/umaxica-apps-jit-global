# typed: false
# frozen_string_literal: true

module SignInOtpResendState
  PURPOSE = "sign-in-otp-resend"
  # Email is the only sign-in OTP channel; SMS OTP is not an accepted sign-in
  # proof, so a telephone state must never be mintable.
  KIND = "email"
  # A resend state is bound to one authentication surface so it cannot be
  # replayed against the other surface's email model and delivery policy.
  SURFACES = %w(app com).freeze
  TTL = 30.minutes
  ENCRYPTOR_CACHE = Concurrent::Map.new

  module_function

  def issue(kind:, target:, surface:)
    raise ArgumentError, "unsupported sign-in OTP resend kind: #{kind}" unless kind.to_s == KIND

    surface_name = surface.to_s
    unless SURFACES.include?(surface_name)
      raise ArgumentError, "unsupported sign-in OTP resend surface: #{surface}"
    end

    encryptor.encrypt_and_sign(
      {
        "kind" => kind.to_s,
        "target" => target.to_s,
        "surface" => surface_name,
      },
      purpose: PURPOSE,
      expires_in: TTL,
    )
  end

  def parse(token)
    return nil if token.blank?

    payload = encryptor.decrypt_and_verify(token, purpose: PURPOSE)
    kind = payload["kind"].to_s
    target = payload["target"].to_s
    surface = payload["surface"].to_s
    return nil if kind.blank? || target.blank? || SURFACES.exclude?(surface)

    { kind: kind, target: target, surface: surface }
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def encryptor
    ENCRYPTOR_CACHE.compute_if_absent(PURPOSE) do
      secret_credential = Rails.application.secret_key_base
      key_len = ActiveSupport::MessageEncryptor.key_len
      key = ActiveSupport::KeyGenerator.new(secret_credential).generate_key(PURPOSE, key_len)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end
  end
end
