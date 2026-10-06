# typed: false
# frozen_string_literal: true

require "digest"
require "json"

module Valkey
  module AuthState
    # Keeps one marker per Base browser locator and ceremony transaction. The Rails session carries
    # only the opaque locator; canceled transactions retain their own marker until their deadline,
    # even when a later intent starts in the same browser.
    class BaseStepUpMarkerStore
      VERSION = 1
      FIELDS = %w(version transaction_ref surface actor_ref session_ref expires_at).freeze

      public

      def initialize(connection: default_connection)
        @connection = connection
      end

      def issue!(locator:, transaction_ref:, surface:, actor_ref:, session_ref:, expires_at:, now: Time.current)
        payload = normalize_payload(
          locator:, transaction_ref:, surface:, actor_ref:, session_ref:, expires_at:, now:,
        )
        key = storage_key(locator:, transaction_ref:)
        encoded = JSON.generate(payload)
        stored = @connection.call("SET", key, encoded, "NX", "EX", [expires_at.to_time - now, 1.second].max.to_i)
        return transaction_ref if stored == "OK"

        existing = @connection.call("GET", key)
        return transaction_ref if existing.to_s.present? && JSON.parse(existing) == payload

        raise Umaxica::Valkey::OperationError, "Base step-up marker collision"
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey Base step-up marker issue unavailable", cause: e
      rescue JSON::ParserError => e
        raise Umaxica::Valkey::SerializationError, "Base step-up marker is corrupt", cause: e
      end

      def read(locator:, transaction_ref:, now: Time.current)
        encoded = @connection.call("GET", storage_key(locator:, transaction_ref:))
        return nil if encoded.to_s.blank?

        payload = JSON.parse(encoded)
        validate_payload!(payload)
        return nil if Time.zone.iso8601(payload.fetch("expires_at")) <= now

        payload
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Umaxica::Valkey::Unavailable, "Valkey Base step-up marker read unavailable", cause: e
      rescue JSON::ParserError, ArgumentError, KeyError, TypeError => e
        raise Umaxica::Valkey::SerializationError, "Base step-up marker is corrupt", cause: e
      end

      private

      def default_connection
        Umaxica::Valkey::Connection.new(
          namespace: Umaxica::Valkey::Namespaces.admission(**Umaxica::Valkey::Namespaces.runtime_scope),
        )
      end

      def storage_key(locator:, transaction_ref:)
        unless locator.is_a?(String) && locator.present? && transaction_ref.is_a?(String) && transaction_ref.present?
          raise ArgumentError, "Base step-up marker identity is invalid"
        end

        digest = Digest::SHA256.hexdigest("base-step-up-marker:#{locator}:#{transaction_ref}")
        @connection.key("base-step-up-marker:#{digest}")
      end

      def normalize_payload(locator:, transaction_ref:, surface:, actor_ref:, session_ref:, expires_at:, now:)
        raise ArgumentError, "Base step-up marker expires_at is invalid" unless expires_at.respond_to?(:to_time)
        raise ArgumentError, "Base step-up marker is expired" unless expires_at.to_time > now

        payload = {
          "version" => VERSION,
          "transaction_ref" => transaction_ref.to_s,
          "surface" => surface.to_s,
          "actor_ref" => actor_ref.to_s,
          "session_ref" => session_ref.to_s,
          "expires_at" => expires_at.to_time.iso8601,
        }
        raise ArgumentError, "Base step-up marker fields are blank" if payload.values_at(
          "transaction_ref", "surface", "actor_ref", "session_ref",
        ).any?(&:blank?)

        payload
      end

      def validate_payload!(payload)
        raise TypeError unless payload.is_a?(Hash) && payload.keys.sort == FIELDS.sort && payload.fetch("version") == VERSION
        raise TypeError if payload.values_at("transaction_ref", "surface", "actor_ref", "session_ref").any?(&:blank?)

        payload
      end
    end
  end
end
