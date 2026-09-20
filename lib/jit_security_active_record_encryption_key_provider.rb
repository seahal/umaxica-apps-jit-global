# typed: false
# frozen_string_literal: true

require "json"
require "digest"

# Centralized key resolution for Active Record encryption rotation.
# Uses Rails.app.creds (ENV -> credentials) for unified lookup.
module JitSecurityActiveRecordEncryptionKeyProvider
  module_function

  # Returns { current: String, previous: [String] }.
  def fetch
    fetch_from_local
  end

  def fetch_from_local
    current = credential_or_fallback(:ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY)
    previous = parse_local_previous
    deterministic = credential_or_fallback(:ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY)
    salt = credential_or_fallback(:ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT)

    { current: current, previous: previous, deterministic: deterministic, key_derivation_salt: salt }
  end

  def parse_local_previous
    raw = optional_credential_value(:ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS)
    return [] if raw.blank?

    Array(JSON.parse(raw))
  rescue JSON::ParserError
    [raw]
  end

  def credential_or_fallback(key)
    value = credential_value(key)
    return value if value.present?

    # The fallback below is derived from public strings, so anyone with the
    # source can recompute it. Gate it on development/test explicitly rather
    # than on "not production": a staging or preview deployment whose RAILS_ENV
    # is not literally "production" would otherwise encrypt real emails, phone
    # numbers, birthdates, and TOTP seeds under a publicly derivable key, with
    # only a log warning. Mirrors JitSessionCookieConfig.force_secure?, which
    # fails closed for unknown environments.
    unless derivable_fallback_permitted?
      raise KeyError,
            "missing credential: #{key} (no derivable fallback outside development and test; " \
            "RAILS_ENV=#{Rails.env})"
    end

    fallback = fallback_key_for(key)
    Rails.logger&.warn("Using local fallback Active Record encryption key for #{key}")
    fallback
  end

  def derivable_fallback_permitted?
    Rails.env.local?
  end

  def credential_value(key)
    creds = Rails.app.creds
    return creds.option(key) if creds.respond_to?(:option) && creds.option(key).present?
    return creds.require(key) if creds.respond_to?(:require)

    nil
  rescue KeyError, RuntimeError
    nil
  end

  def optional_credential_value(key)
    creds = Rails.app.creds
    return creds.option(key) if creds.respond_to?(:option)

    nil
  rescue KeyError, RuntimeError
    nil
  end

  def fallback_key_for(key)
    Digest::SHA256.hexdigest("jit-active-record-encryption:#{Rails.env}:#{key}")
  end

  private_class_method :derivable_fallback_permitted?, :fallback_key_for
end
