# typed: false
# frozen_string_literal: true

require "jwt"
require "jit_security_jwt_registry"

# Resolves the fixed preference realm issuer, key and clock-skew configuration.
module PreferenceJwtConfiguration
  def self.active_kid(issuer_id)
    JitSecurityJwtRegistry.issuer(issuer_id).current_kid ||
      raise(JitSecurityJwtRegistry::ConfigurationError, "#{issuer_id} active kid is not configured")
  end

  def self.leeway_seconds
    SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS
  end

  def self.com_issuer
    ENV.fetch("PREFERENCE_COM_JWT_REVOKED_KIDS")
    record = JitSecurityJwtRegistry.issuer("preference_com")
    unless record.issuer.present? && record.audiences == ["com"] && record.current_kid.present?
      raise JitSecurityJwtRegistry::ConfigurationError, "com preference JWT issuer, audience or active key is missing"
    end

    record.issuer
  end

  def self.issuer_for(issuer_id)
    return com_issuer if issuer_id == "preference_com"

    expected_audience =
      case issuer_id
      when "preference_app" then "app"
      when "preference_org" then "org"
      else raise JitSecurityJwtRegistry::ConfigurationError, "unsupported preference issuer: #{issuer_id.inspect}"
      end
    record = JitSecurityJwtRegistry.issuer(issuer_id)
    unless record.issuer.present? && record.audiences == [expected_audience] && record.current_kid.present?
      raise JitSecurityJwtRegistry::ConfigurationError,
            "#{issuer_id} preference JWT issuer, audience or active key is missing"
    end

    record.issuer
  end

  def self.validate!
    issuer_for("preference_app")
    issuer_for("preference_org")
    com_issuer
    true
  end

  def self.private_key_for_active(issuer_id)
    private_key_for(active_kid(issuer_id), issuer_id: issuer_id)
  end

  def self.private_key_for(kid, issuer_id:)
    JitSecurityJwtRegistry.private_key_for(issuer_id, kid)
  end

  def self.public_key_for(kid, issuer_id:)
    JitSecurityJwtRegistry.public_key_for(issuer_id, kid)
  end

  def self.parse_header(token)
    JitSecurityJwtRegistry.parse_header(token)
  end

  public_class_method :active_kid, :leeway_seconds, :com_issuer, :issuer_for, :validate!,
                      :private_key_for_active, :private_key_for, :public_key_for, :parse_header
end
