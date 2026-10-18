# typed: false
# frozen_string_literal: true

require "base64"

module Webauthn
  # Normalizes WebAuthn creation/request options for JSON delivery to the
  # browser. src/controllers/webauthn_utils.js expects every binary field
  # (challenge, user.id, credential ids) as unpadded Base64URL.
  module OptionsSerializer
    module_function

    def as_json(options)
      data = options.respond_to?(:as_json) ? options.as_json : options
      normalized = data.deep_stringify_keys

      source_challenge =
        if options.respond_to?(:challenge)
          options.challenge
        else
          normalized["challenge"]
        end
      normalized["challenge"] = normalize_id(source_challenge)

      if normalized["user"].is_a?(Hash)
        source_user_id =
          if options.respond_to?(:user) && options.user.respond_to?(:id)
            options.user.id
          else
            normalized["user"]["id"]
          end
        # User IDs from the WebAuthn gem are raw bytes, not Base64URL encoded.
        # Always force-encode to avoid passing numeric strings (e.g. "980190962")
        # that match the Base64URL character set but produce invalid padding in atob().
        normalized["user"]["id"] = Base64.urlsafe_encode64(source_user_id.to_s.b, padding: false)
      end

      normalize_credential_list_ids!(normalized, "excludeCredentials")
      normalize_credential_list_ids!(normalized, "allowCredentials")

      normalized
    end

    def normalize_credential_list_ids!(data, key)
      list = data[key] || data[key.underscore]
      return unless list.is_a?(Array)

      normalized_list =
        list.map do |credential|
          next credential unless credential.is_a?(Hash)

          credential.merge("id" => normalize_id(credential["id"]))
        end

      if data.key?(key)
        data[key] = normalized_list
      else
        data[key.underscore] = normalized_list
      end
    end

    def normalize_id(value)
      return value if value.nil?

      if value.is_a?(String)
        return value if value.match?(/\A[A-Za-z0-9_-]+\z/)

        return Base64.urlsafe_encode64(value.b, padding: false)
      end
      return Base64.urlsafe_encode64(value.pack("C*"), padding: false) if value.is_a?(Array)
      return Base64.urlsafe_encode64(value.to_s.b, padding: false) if value.is_a?(Integer)

      value
    end
    private_class_method :normalize_credential_list_ids!, :normalize_id
  end
end
