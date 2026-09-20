# typed: false
# frozen_string_literal: true

require "set"
require "jit_security_jwt_issuer_record"
require "jit_security_jwt_key_material"
require "jit_security_jwt_jwk"
require "jit_security_jwt_jwks"

module JitSecurityJwtIssuerBuilder
  module_function

  Error = Class.new(StandardError)

  def build_keyset_issuer(id:, private_keyset:, private_keyset_source:, public_keyset:, public_keyset_source:,
                          active_kid:, issuer:, audiences:, revoked_kids:)
    private_keys = parse_private_keyset(private_keyset, source: private_keyset_source)
    public_keys = parse_public_jwk_collection(public_keyset, source: public_keyset_source)
    current_kid = active_kid.presence || private_keys.keys.first
    keys = merge_keys(
      private_keys: private_keys, public_jwks: public_keys, current_kid: current_kid,
      revoked_kids: revoked_kids,
    )

    JitSecurityJwtIssuerRecord.new(
      id: id,
      namespace: id.upcase,
      issuer: issuer,
      audiences: audiences,
      current_kid: current_kid,
      keys: keys,
      revoked_kids: revoked_kids.to_set.freeze,
    )
  end

  def build_surface_issuer(namespace:, active_kid:, private_key:, private_key_source:, public_keyset:,
                           public_keyset_source:, revoked_kids:, issuer:, audiences:)
    build_surface_issuer_record(
      namespace: namespace,
      id: "surface:#{namespace}",
      active_kid: active_kid,
      private_key: private_key,
      private_key_source: private_key_source,
      public_keyset: public_keyset,
      public_keyset_source: public_keyset_source,
      revoked_kids: revoked_kids,
      issuer: issuer,
      audiences: audiences,
    )
  end

  def build_surface_issuer_record(namespace:, id:, active_kid:, private_key:, private_key_source:, public_keyset:,
                                  public_keyset_source:, revoked_kids:, issuer:, audiences:)
    active_private_key = decode_private_key(private_key, source: private_key_source)
    current_public_jwk =
      (active_kid && active_private_key) ? JitSecurityJwtJwk.export_public(active_private_key, kid: active_kid) : nil
    public_jwks = parse_public_jwk_collection(public_keyset, source: public_keyset_source)
    revoked_kids = revoked_kids.to_set

    if active_kid && current_public_jwk && public_jwks[active_kid] &&
        public_jwks[active_kid].except("state") != current_public_jwk
      raise Error, "surface:#{namespace} active public JWK does not match active private key"
    end

    public_jwks[active_kid] = current_public_jwk.merge("state" => "active") if current_public_jwk

    keys = public_jwks.each_with_object({}) do |(kid, jwk), acc|
      state = key_state_for(
        kid: kid, current_kid: active_kid, configured_state: jwk["state"],
        revoked_kids: revoked_kids,
      )
      acc[kid] = KeyRecord.new(
        kid: kid,
        private_key: (kid == active_kid) ? active_private_key : nil,
        public_key: JitSecurityJwtJwk.import_public_key(jwk),
        public_jwk: jwk.except("state"),
        state: state,
      )
    rescue JitSecurityJwtJwk::Error => e
      raise Error, "#{public_keyset_source} #{e.message}"
    end.freeze

    JitSecurityJwtIssuerRecord.new(
      id: id,
      namespace: namespace,
      issuer: issuer,
      audiences: audiences.freeze,
      current_kid: active_kid,
      keys: keys,
      revoked_kids: revoked_kids.freeze,
    )
  end

  def merge_keys(private_keys:, public_jwks:, current_kid:, revoked_kids:)
    revoked_kids = revoked_kids.to_set
    merged = {}
    public_jwks.each do |kid, jwk|
      merged[kid] = KeyRecord.new(
        kid: kid,
        private_key: nil,
        public_key: import_public_key(jwk),
        public_jwk: jwk.except("state"),
        state: key_state_for(
          kid: kid, current_kid: current_kid, configured_state: jwk["state"],
          revoked_kids: revoked_kids,
        ),
      )
    end

    private_keys.each do |kid, private_key|
      derived_jwk = JitSecurityJwtJwk.export_public(private_key, kid: kid)
      if public_jwks[kid] && public_jwks[kid].except("state") != derived_jwk
        raise Error, "active/private key #{kid.inspect} does not match configured public JWK"
      end

      state = key_state_for(
        kid: kid, current_kid: current_kid, configured_state: public_jwks.dig(kid, "state"),
        revoked_kids: revoked_kids,
      )
      merged[kid] = KeyRecord.new(
        kid: kid,
        private_key: private_key,
        public_key: private_key,
        public_jwk: derived_jwk,
        state: state,
      )
    end

    merged.freeze
  end

  def key_state_for(kid:, current_kid:, configured_state:, revoked_kids:)
    return "revoked" if revoked_kids.include?(kid)
    return "active" if kid == current_kid

    configured_state.presence || "grace"
  end

  def parse_private_keyset(raw, source:)
    JitSecurityJwtKeyMaterial.parse_private_keyset(raw)
  rescue JitSecurityJwtKeyMaterial::Error => e
    raise Error, "#{source} #{e.message}"
  end

  def parse_public_jwk_collection(raw, source:)
    JitSecurityJwtJwks.parse_public_collection(raw)
  rescue JitSecurityJwtJwks::Error => e
    raise Error, "#{source} #{e.message}"
  end

  def decode_private_key(value, source:)
    JitSecurityJwtKeyMaterial.decode_private_key(value)
  rescue JitSecurityJwtKeyMaterial::Error => e
    raise Error, "#{source} #{e.message}"
  end

  def import_public_key(jwk)
    JitSecurityJwtJwk.import_public_key(jwk)
  rescue JitSecurityJwtJwk::Error => e
    raise Error, e.message
  end

  private_class_method :key_state_for
end
