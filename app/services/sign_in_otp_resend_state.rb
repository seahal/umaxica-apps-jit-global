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

  def issue(kind:, target:, surface:, browser_binding:, contact:)
    raise ArgumentError, "unsupported sign-in OTP resend kind: #{kind}" unless kind.to_s == KIND

    surface_name = surface.to_s
    unless SURFACES.include?(surface_name)
      raise ArgumentError, "unsupported sign-in OTP resend surface: #{surface}"
    end

    expected_model = (surface_name == "app") ? ClientEmail : VisitorEmail
    unless contact.nil? || contact.is_a?(expected_model)
      raise ArgumentError, "resend Contact does not match surface"
    end

    encryptor.encrypt_and_sign(
      {
        "kind" => kind.to_s,
        "target" => target.to_s,
        "surface" => surface_name,
        "version" => "2",
      }.merge(contact_snapshot(contact)),
      purpose: binding_purpose(browser_binding),
      expires_in: TTL,
    )
  end

  def parse(token, browser_binding:)
    return nil if token.blank?

    payload = encryptor.decrypt_and_verify(token, purpose: binding_purpose(browser_binding))
    return nil if payload.nil?
    return nil unless payload["version"] == "2"

    kind = payload["kind"].to_s
    target = payload["target"].to_s
    surface = payload["surface"].to_s
    return nil if kind.blank? || target.blank? || SURFACES.exclude?(surface)

    {
      kind: kind,
      target: target,
      surface: surface,
      contact_mode: payload.fetch("contact_mode"),
      contact_ref: payload.fetch("contact_ref"),
      owner_ref: payload.fetch("owner_ref"),
      binding_fact: payload.fetch("binding_fact"),
    }
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def binding_purpose(browser_binding)
    unless browser_binding.is_a?(String) && browser_binding.match?(/\A[0-9a-f]{64}\z/)
      raise ArgumentError, "resend state requires a server-owned browser binding"
    end

    "#{PURPOSE}:#{browser_binding}"
  end
  private_class_method :binding_purpose

  def contact_snapshot(contact)
    # Both modes use equal-width strings; encrypted state length must not disclose existence.
    return {
      "contact_mode" => "fake",
      "contact_ref" => "0" * 21,
      "owner_ref" => "0" * 20,
      "binding_fact" => "0000-00-00T00:00:00.000000Z",
    } if contact.nil?

    raise ArgumentError, "resend state requires an effective Contact" unless contact.binding_effective?

    owner_id = contact.is_a?(ClientEmail) ? contact.user_id : contact.visitor_id
    {
      "contact_mode" => "real",
      "contact_ref" => contact.public_id.to_s,
      "owner_ref" => owner_id.to_s.rjust(20, "0"),
      "binding_fact" => contact.binding_finalized_at.utc.iso8601(6),
    }
  end
  private_class_method :contact_snapshot

  def encryptor
    ENCRYPTOR_CACHE.compute_if_absent(PURPOSE) do
      secret_credential = Rails.application.secret_key_base
      key_len = ActiveSupport::MessageEncryptor.key_len
      key = ActiveSupport::KeyGenerator.new(secret_credential).generate_key(PURPOSE, key_len)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end
  end
end
