# typed: false
# frozen_string_literal: true

require "base64"
require "fileutils"
require "json"
require "jit_log_event"
require "jit_security_jwt_jwk"
require "openssl"

module JitSecurityJwtLocalKeysetInstaller
  module_function

  DEFAULT_STORE_PATH = Rails.root.join("tmp/local_jwt_keysets.json")

  def install!(store_path: DEFAULT_STORE_PATH)
    store = load_store(store_path)
    changed = false

    changed |= install_keyset_issuer!(
      store,
      prefix: "AUTH",
      kid: "#{Rails.env}-auth-es384-a",
    )
    changed |= install_keyset_issuer!(
      store,
      prefix: "PREFERENCE",
      kid: "#{Rails.env}-preference-es384-a",
    )

    JitSecurityJwtRegistry::SURFACE_NAMESPACES.each do |namespace|
      changed |= install_surface_issuer!(
        store,
        namespace: namespace,
        kid: "#{Rails.env}-#{namespace.downcase.tr("_", "-")}-es384-a",
      )
    end
    JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES.each do |namespace|
      changed |= install_oidc_client_issuer!(
        store,
        namespace: namespace,
        kid: "#{Rails.env}-oidc-client-#{namespace.downcase.tr("_", "-")}-es384-a",
      )
    end

    write_store(store_path, store) if changed
    true
  end

  def install_keyset_issuer!(store, prefix:, kid:)
    active_name = "#{prefix}_JWT_ACTIVE_KID"
    private_name = "#{prefix}_JWT_PRIVATE_KEYSET"
    public_name = "#{prefix}_JWT_PUBLIC_KEYSET"
    return false if complete_env?(active_name, private_name, public_name)

    env_values =
      if store.key?(prefix)
        store.fetch(prefix)
      else
        warn_local_keyset_regenerated(issuer: prefix, kid: kid)
        keyset_issuer_env(kid)
      end
    store[prefix] = env_values

    ENV[active_name] = env_values.fetch("active_kid")
    ENV[private_name] = env_values.fetch("private_keyset")
    ENV[public_name] = env_values.fetch("public_keyset")
    true
  end

  # Surface keys sign Jump RTs, so in local environments they come only from this installer's
  # store. An ENV value that did not come from the store (for example copied production signing
  # material) is a configuration error rather than something to keep or silently replace. Values
  # this installer exported on an earlier call in the same process match the store and pass.
  def install_surface_issuer!(store, namespace:, kid:)
    store_key = "JWT_#{namespace}"
    names = {
      "active_kid" => "JWT_#{namespace}_ACTIVE_KID",
      "private_key" => "JWT_#{namespace}_PRIVATE_KEY",
      "public_keyset" => "JWT_#{namespace}_PUBLIC_KEYSET",
    }
    preset = names.select { |_field, name| ENV.key?(name) }
    stored = store[store_key]
    unless preset.empty? || (stored && preset.all? { |field, name| ENV[name] == stored[field] })
      raise ArgumentError,
            "#{preset.values.join(", ")} must not be set in #{Rails.env}; local surface signing keys are owned by " \
            "#{DEFAULT_STORE_PATH.basename}"
    end
    active_name = names.fetch("active_kid")
    private_name = names.fetch("private_key")
    public_name = names.fetch("public_keyset")
    env_values =
      if stored
        stored
      else
        warn_local_keyset_regenerated(issuer: store_key, kid: kid)
        surface_issuer_env(kid)
      end
    store[store_key] = env_values

    ENV[active_name] = env_values.fetch("active_kid")
    ENV[private_name] = env_values.fetch("private_key")
    ENV[public_name] = env_values.fetch("public_keyset")
    true
  end

  def install_oidc_client_issuer!(store, namespace:, kid:)
    active_name = "OIDC_CLIENT_#{namespace}_ACTIVE_KID"
    private_name = "OIDC_CLIENT_#{namespace}_PRIVATE_KEY"
    public_name = "OIDC_CLIENT_#{namespace}_PUBLIC_KEYSET"
    return false if complete_env?(active_name, private_name, public_name)

    store_key = "OIDC_CLIENT_#{namespace}"
    env_values =
      if store.key?(store_key)
        store.fetch(store_key)
      else
        warn_local_keyset_regenerated(issuer: store_key, kid: kid)
        surface_issuer_env(kid)
      end
    store[store_key] = env_values

    ENV[active_name] = env_values.fetch("active_kid")
    ENV[private_name] = env_values.fetch("private_key")
    ENV[public_name] = env_values.fetch("public_keyset")
    true
  end

  def complete_env?(*names)
    names.all? { |name| ENV[name].present? }
  end

  # Freshly minted local signing keys mean any token issued before this
  # boot (still sitting in a browser cookie) will fail verification. In
  # dev/test that surfaces as "access token rejected after restart ->
  # cookie discarded -> new token issued". The store normally prevents it
  # by persisting keys across boots, so a regeneration almost always means
  # the store under tmp/ was cleared (rails tmp:clear, fresh clone, CI,
  # container rebuild). Warn loudly so the cause is obvious in the log.
  def warn_local_keyset_regenerated(issuer:, kid:)
    Rails.logger.warn(
      JitLogEvent.format(
        "jwt.local_keyset.regenerated",
        issuer: issuer,
        kid: kid,
        env: Rails.env,
        store_path: DEFAULT_STORE_PATH.to_s,
        impact: "tokens issued before this boot for this issuer will fail verification until reissued",
      ),
    )
  end

  def load_store(path)
    return {} unless File.exist?(path)

    parsed = JSON.parse(File.read(path))
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError => e
    Rails.logger.warn(
      JitLogEvent.format(
        "jwt.local_keyset_store.malformed",
        error_class: e.class.name,
        path: path.to_s,
      ),
    )
    {}
  end

  def write_store(path, store)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(store), mode: "w", perm: 0o600)
  end

  def keyset_issuer_env(kid)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    {
      "active_kid" => kid,
      "private_keyset" => JSON.generate(kid => base64_der(key)),
      "public_keyset" => JSON.generate("keys" => [public_jwk(key, kid)]),
    }
  end

  def surface_issuer_env(kid)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    {
      "active_kid" => kid,
      "private_key" => base64_der(key),
      "public_keyset" => JSON.generate("keys" => [public_jwk(key, kid)]),
    }
  end

  def public_jwk(key, kid)
    JitSecurityJwtJwk.export_public(key, kid: kid).merge("state" => "active")
  end

  def base64_der(key)
    Base64.strict_encode64(key.to_der)
  end

  private_class_method :install_keyset_issuer!, :install_surface_issuer!, :install_oidc_client_issuer!,
                       :complete_env?, :warn_local_keyset_regenerated, :load_store, :write_store, :keyset_issuer_env,
                       :surface_issuer_env
end
