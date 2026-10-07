# typed: false
# frozen_string_literal: true

# Explicit WebAuthn surface declaration for controllers.
#
# Each surface's auth base controller declares its surface once:
#
#   webauthn_surface :app
#
# Ceremony code then reads webauthn_surface / webauthn_relying_party_config.
# There is intentionally no default and no inference from class names or the
# request host: an undeclared surface raises before any ceremony can run.
module WebauthnSurfaceDeclarable
  extend ActiveSupport::Concern

  class SurfaceNotDeclaredError < StandardError; end

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    class_attribute :declared_webauthn_surface_key, instance_writer: false, default: nil # rubocop:disable ThreadSafety/ClassAndModuleAttributes
  end

  class_methods do
    def webauthn_surface(key)
      self.declared_webauthn_surface_key = Webauthn::Surface.for(key).key
    end
  end

  def webauthn_surface
    key = self.class.declared_webauthn_surface_key
    if key.nil?
      raise SurfaceNotDeclaredError,
            "#{self.class.name} performs WebAuthn ceremonies but does not declare webauthn_surface"
    end

    Webauthn::Surface.for(key)
  end

  def webauthn_relying_party_config
    @webauthn_relying_party_config ||= Webauthn::RelyingPartyConfigResolver.resolve(webauthn_surface)
  end
end
